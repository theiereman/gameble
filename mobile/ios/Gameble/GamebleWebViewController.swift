import HotwireNative
import UIKit
import WebKit

final class GamebleWebViewController: HotwireWebViewController {
    private var tabsShown = true
    private lazy var aboveTabs = visitableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    private lazy var toScreenEdge = visitableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)

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
        view.backgroundColor = tabBarController == nil ? Palette.panel : Palette.ground
        fitBottom()
    }

    override func visitableDidActivateWebView(_ webView: WKWebView) {
        super.visitableDidActivateWebView(webView)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = false
    }

    func showTabs(_ shown: Bool) {
        tabsShown = shown
        tabBarController?.tabBar.isHidden = !shown
        fitBottom()
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
