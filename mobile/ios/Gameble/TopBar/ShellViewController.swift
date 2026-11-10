import HotwireNative
import UIKit
import WebKit

final class ShellViewController: UIViewController {
    let tabs: HotwireTabBarController

    private let topBar = TopBarView()
    private let statusBackdrop = UIView()
    private let pullConsole = PullConsoleView()
    private lazy var pullConsoleTop = pullConsole.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: Self.consoleTucked)
    private var refreshStart: CFTimeInterval?
    private var consoleHides = 0
    private var barShown = true

    private static let slideDuration: TimeInterval = 0.2
    private static let layerDuration: TimeInterval = 0.26
    private static let consoleTucked = -PullConsoleView.size.height
    private static let consoleRevealed: CGFloat = 6
    private static let consoleDoneHold: TimeInterval = 0.45
    private static let consoleTuckDuration: TimeInterval = 0.22

    init(tabs: HotwireTabBarController) {
        self.tabs = tabs
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ground
        addChild(tabs)
        view.addSubview(tabs.view)
        pinToEdges(tabs.view)
        tabs.didMove(toParent: self)

        statusBackdrop.translatesAutoresizingMaskIntoConstraints = false
        statusBackdrop.backgroundColor = Palette.steamBar
        view.addSubview(pullConsole)
        view.addSubview(topBar)
        view.addSubview(statusBackdrop)
        NSLayoutConstraint.activate([
            pullConsole.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pullConsoleTop,
            statusBackdrop.topAnchor.constraint(equalTo: view.topAnchor),
            statusBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBackdrop.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        topBar.onBack = { [weak self] in self?.goBack() }
        topBar.onCapsules = { TopBarNavigation.shared.open("/booster") }
        topBar.onBell = { [weak self] in self?.togglePanel("bell") }
        topBar.onMenu = { [weak self] in self?.togglePanel("menu") }
        render(TopBarStore.shared.state)
        TopBarStore.shared.onChange = { [weak self] state in self?.render(state) }
    }

    private func render(_ state: TopBarState) {
        topBar.render(state)
        Tabs.showBadges(of: state, on: tabs.tabBar)
    }

    func screenWillAppear(_ screen: UIViewController) {
        topBar.show(leftSide(of: screen))
        setBarShown(true)
    }

    func refreshLeftSide() {
        guard let screen = activeStack.topViewController else { return }
        topBar.show(leftSide(of: screen))
    }

    func setBarShown(_ shown: Bool) {
        guard shown != barShown else { return }
        barShown = shown
        if !shown { sendPanel(nil) }
        let move = { [topBar] in
            topBar.transform = shown ? .identity : CGAffineTransform(translationX: 0, y: -TopBarView.height)
        }
        if UIAccessibility.isReduceMotionEnabled {
            move()
        } else {
            UIView.animate(withDuration: Self.slideDuration, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: move)
        }
    }

    func showPull(progress: CGFloat) {
        consoleHides += 1
        if progress > 0 { setBarShown(true) }
        pullConsole.show(.pulling(progress))
        if progress > 0 { revealConsole(progress) } else { tuckConsole() }
    }

    func showRefreshing(_ refreshing: Bool) {
        consoleHides += 1
        if refreshing {
            setBarShown(true)
            refreshStart = CACurrentMediaTime()
            pullConsole.show(.refreshing(since: refreshStart ?? 0))
            revealConsole(1)
        } else if let start = refreshStart {
            refreshStart = nil
            pullConsole.show(.done(took: CACurrentMediaTime() - start))
            let hide = consoleHides
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.consoleDoneHold) { [weak self] in
                guard let self, self.consoleHides == hide else { return }
                self.tuckConsole()
            }
        }
    }

    private func revealConsole(_ progress: CGFloat) {
        let reach = min(1, progress)
        pullConsoleTop.constant = Self.consoleTucked + reach * (Self.consoleRevealed - Self.consoleTucked)
        pullConsole.alpha = min(1, reach * 1.6)
    }

    private func tuckConsole() {
        pullConsoleTop.constant = Self.consoleTucked
        let tuck = { [view, pullConsole] in
            pullConsole.alpha = 0
            view?.layoutIfNeeded()
        }
        UIAccessibility.isReduceMotionEnabled ? tuck() : UIView.animate(withDuration: Self.consoleTuckDuration, delay: 0, options: [.curveEaseIn, .beginFromCurrentState], animations: tuck)
    }

    func setBarDimmed(_ dimmed: Bool) {
        topBar.setDimmed(dimmed)
        if dimmed { setBarShown(true) }
    }

    func showLayer(_ layer: UIViewController) {
        addChild(layer)
        view.insertSubview(layer.view, belowSubview: pullConsole)
        pinToEdges(layer.view)
        view.layoutIfNeeded()
        layer.view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
        UIView.animate(withDuration: Self.layerDuration, delay: 0, options: .curveEaseOut) {
            layer.view.transform = .identity
        } completion: { _ in
            layer.didMove(toParent: self)
        }
    }

    func hideLayer(_ layer: UIViewController, animated: Bool, finished: (() -> Void)?) {
        layer.willMove(toParent: nil)
        let remove = {
            layer.view.removeFromSuperview()
            layer.removeFromParent()
            finished?()
        }
        revealTabs()
        guard animated else { return remove() }
        UIView.animate(withDuration: Self.layerDuration, delay: 0, options: .curveEaseIn) {
            layer.view.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
        } completion: { _ in
            remove()
        }
    }

    private var activeStack: UINavigationController {
        TopBarNavigation.shared.layerStack ?? tabs.activeNavigator.rootViewController
    }

    // The tabs never left the screen, so UIKit does not tell their top screen it is back on view.
    private func revealTabs() {
        let screen = tabs.activeNavigator.rootViewController.topViewController as? GamebleWebViewController
        screen?.revealed()
    }

    private func leftSide(of screen: UIViewController) -> TopBarView.Left {
        let stack = screen.navigationController?.viewControllers ?? []
        if let index = stack.firstIndex(of: screen), index > 0 {
            return .back(backLabel(of: stack[index - 1]))
        }
        guard TopBarNavigation.shared.isLayer(screen.navigationController) else { return .home }
        return .back(backLabel(of: tabs.activeNavigator.rootViewController.topViewController))
    }

    private func backLabel(of screen: UIViewController?) -> String {
        let url = (screen as? Visitable)?.currentVisitableURL
        return url.flatMap(ScreenLabels.label(for:)) ?? Gameble.text("Back", "Retour")
    }

    private func goBack() {
        if activeStack.viewControllers.count > 1 {
            activeStack.popViewController(animated: true)
        } else {
            TopBarNavigation.shared.closeLayer()
        }
    }

    private func togglePanel(_ panel: String) {
        guard (activeStack.topViewController as? GamebleWebViewController)?.pageIsReady == true else { return }
        sendPanel(panel)
    }

    private func sendPanel(_ panel: String?) {
        let wanted = panel.map { "'\($0)'" } ?? "null"
        activeWebView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('gameble:top-bar-panel', { detail: { panel: \(wanted) } }))")
    }

    private var activeWebView: WKWebView {
        TopBarNavigation.shared.layerWebView ?? tabs.activeNavigator.activeWebView
    }

    private func pinToEdges(_ child: UIView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: view.topAnchor),
            child.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
