import HotwireNative
import UIKit
import WebKit

final class GamebleWebViewController: HotwireWebViewController {
    private(set) var pageIsReady = false

    private var reloadingBlankPage = false

    private var tabsShown = true
    private var pullsToRefresh = false
    private var pullHeld = false
    private var refreshing = false
    private var pullGesture = PullGesture()
    private var dialogOpen = false
    private var topBarScroll = TopBarScroll()
    private var scrollObservation: NSKeyValueObservation?
    private lazy var aboveTabs = visitableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    private lazy var toScreenEdge = visitableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)

    private var isSheet: Bool {
        tabBarController == nil && !TopBarNavigation.shared.isLayer(navigationController)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NSLayoutConstraint.deactivate(view.constraints.filter {
            $0.firstItem === visitableView && [.top, .bottom].contains($0.firstAttribute)
        })
        visitableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        fitBottom()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.backgroundColor = isSheet ? Palette.panel : Palette.ground
        fitBottom()
        if !isSheet { tellBarAboutThisScreen() }
        // A cancelled edge swipe leaves this screen covered again by the one it was revealing.
        transitionCoordinator?.animate(alongsideTransition: nil) { context in
            if context.isCancelled { TopBarNavigation.shared.shell?.refreshLeftSide() }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        announceShown(on: visitableView.webView)
        reloadIfBlank()
    }

    override func visitableDidRender() {
        super.visitableDidRender()
        pageIsReady = true
        reloadingBlankPage = false
        finishRefresh()
    }

    override func visitableDidActivateWebView(_ webView: WKWebView) {
        super.visitableDidActivateWebView(webView)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        takeOverPullToRefresh()
        webView.scrollView.alwaysBounceVertical = pullsToRefresh
        scrollObservation = webView.scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
            self?.scrolled(scrollView)
        }
        if view.window != nil { announceShown(on: webView) }
    }

    override func visitableDidDeactivateWebView() {
        scrollObservation = nil
        finishRefresh()
        super.visitableDidDeactivateWebView()
    }

    func revealed() {
        tellBarAboutThisScreen()
        announceShown(on: visitableView.webView)
        reloadIfBlank()
    }

    func showTabs(_ shown: Bool) {
        tabsShown = shown
        tabBarController?.tabBar.isHidden = !shown
        fitBottom()
    }

    func holdPullToRefresh() {
        pullHeld = true
        if let change = pullGesture.cancel() { show(change) }
    }

    func releasePullToRefresh() {
        pullHeld = false
    }

    private func takeOverPullToRefresh() {
        guard visitableView.allowsPullToRefresh else { return }
        pullsToRefresh = true
        visitableView.allowsPullToRefresh = false
    }

    private func followPull(_ scrollView: UIScrollView) {
        guard pullsToRefresh, !pullHeld, !refreshing else { return }
        if let change = pullGesture.moved(to: scrollView.contentOffset.y, tracking: scrollView.isTracking) { show(change) }
    }

    private func show(_ change: PullGesture.Change) {
        let shell = TopBarNavigation.shared.shell
        switch change {
        case .pulled(let progress, let reachedFull):
            if reachedFull { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            shell?.showPull(progress: progress)
        case .letGo(refresh: true):
            startRefresh()
        case .letGo(refresh: false):
            shell?.showPull(progress: 0)
        }
    }

    private func startRefresh() {
        refreshing = true
        TopBarNavigation.shared.shell?.showRefreshing(true)
        refreshInPlace()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.refreshTimeout) { [weak self] in self?.finishRefresh() }
    }

    // Hotwire's reload cold-boots the page behind a spinner; a Turbo visit keeps the screen until the new one renders.
    private func refreshInPlace() {
        guard let webView = visitableView.webView else { return reloadVisitable() }
        webView.callAsyncJavaScript(Self.refreshInPlaceScript, arguments: [:], in: nil, in: .page) { [weak self] result in
            guard let self, self.refreshing else { return }
            if case .success(let refreshed) = result, refreshed as? Bool == true {
                self.finishRefresh()
            } else {
                self.reloadVisitable()
            }
        }
    }

    private static let refreshInPlaceScript = """
        if (!window.Turbo) return false
        await new Promise((resolve) => {
          const settle = () => {
            document.removeEventListener("turbo:load", settle)
            document.removeEventListener("turbo:fetch-request-error", settle)
            resolve()
          }
          document.addEventListener("turbo:load", settle)
          document.addEventListener("turbo:fetch-request-error", settle)
          Turbo.visit(location.href, { action: "replace" })
        })
        return true
        """

    private func finishRefresh() {
        guard refreshing else { return }
        refreshing = false
        TopBarNavigation.shared.shell?.showRefreshing(false)
    }

    private static let refreshTimeout: TimeInterval = 12

    func dialogChanged(open: Bool) {
        dialogOpen = open
        guard !isSheet, TopBarNavigation.shared.isOnView(self) else { return }
        TopBarNavigation.shared.shell?.setBarDimmed(open)
    }

    private func tellBarAboutThisScreen() {
        let shell = TopBarNavigation.shared.shell
        shell?.screenWillAppear(self)
        shell?.setBarDimmed(dialogOpen)
        topBarScroll.reset(at: visitableView.webView?.scrollView.contentOffset.y ?? 0)
    }

    private func scrolled(_ scrollView: UIScrollView) {
        guard !isSheet, TopBarNavigation.shared.isOnView(self) else { return }
        followPull(scrollView)
        let position = scrollView.contentOffset.y
        guard scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating else {
            topBarScroll.reset(at: position)
            return
        }
        let furthest = scrollView.contentSize.height - scrollView.bounds.height
        if let shown = topBarScroll.barShownAfterMoving(to: position, furthest: furthest) {
            TopBarNavigation.shared.shell?.setBarShown(shown)
        }
    }

    private func announceShown(on webView: WKWebView?) {
        webView?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('gameble:screen-shown'))")
    }

    // iOS ends the web process of a screen off view under memory pressure, and nothing reloads it when that screen comes back.
    private func reloadIfBlank() {
        guard pageIsReady, !reloadingBlankPage, let webView = visitableView.webView else { return }
        webView.evaluateJavaScript("document.body?.childElementCount ?? 0") { [weak self] elements, error in
            guard let self, self.visitableView.webView === webView, !self.reloadingBlankPage else { return }
            guard error != nil || (elements as? Int) == 0 else { return }
            self.reloadingBlankPage = true
            self.reloadVisitable()
        }
    }

    private func fitBottom() {
        let keepsClearOfTabs = tabBarController != nil && tabsShown
        toScreenEdge.isActive = !keepsClearOfTabs
        aboveTabs.isActive = keepsClearOfTabs
        additionalSafeAreaInsets.bottom = tabBarController != nil && !tabsShown ? -hiddenTabsInset : 0
    }

    // UIKit keeps a hidden tab bar's height in its children's safe area, which the page would pad as empty space.
    private var hiddenTabsInset: CGFloat {
        let screenEdgeInset = view.window?.safeAreaInsets.bottom ?? 0
        let inheritedInset = view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom
        return max(0, inheritedInset - screenEdgeInset)
    }
}
