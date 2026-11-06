import HotwireNative
import UIKit
import WebKit

final class TopBarNavigation {
    static let shared = TopBarNavigation()

    weak var shell: ShellViewController?
    private var layer: Navigator?

    var layerStack: UINavigationController? {
        layer?.rootViewController
    }

    var layerWebView: WKWebView? {
        layer?.activeWebView
    }

    func open(_ path: String) {
        guard let url = URL(string: path, relativeTo: Gameble.rootURL)?.absoluteURL else { return }
        let destination = Tabs.destination(of: path)
        guard let tab = destination.tab else { return openAboveTabs(url) }
        closeLayer { [weak self] in
            self?.show(tab: tab, visiting: destination.atRoot ? nil : url)
        }
    }

    func isLayer(_ viewController: UIViewController?) -> Bool {
        viewController != nil && viewController === layer?.rootViewController
    }

    // A screen under the layer is still in the window, yet not on view.
    func isOnView(_ viewController: UIViewController) -> Bool {
        guard viewController.viewIfLoaded?.window != nil else { return false }
        return layer == nil || isLayer(viewController.navigationController)
    }

    func closeLayer(animated: Bool = true, then finished: (() -> Void)? = nil) {
        guard let layer else {
            finished?()
            return
        }
        self.layer = nil
        shell?.hideLayer(layer.rootViewController, animated: animated, finished: finished)
    }

    private func openAboveTabs(_ url: URL) {
        if let layer {
            layer.route(url)
            return
        }
        let navigator = Navigator(configuration: .init(name: "layer", startLocation: url))
        navigator.start()
        layer = navigator
        shell?.showLayer(navigator.rootViewController)
    }

    private func show(tab: Int, visiting url: URL?) {
        guard let tabs = shell?.tabs else { return }
        tabs.selectedIndex = tab
        let navigator = tabs.activeNavigator
        navigator.clearAll()
        if let url { navigator.route(url) }
    }
}
