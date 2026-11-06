import HotwireNative
import UIKit

final class TopBarNavigation {
    static let shared = TopBarNavigation()

    weak var tabBarController: HotwireTabBarController?
    private var layer: Navigator?

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

    func closeLayer(animated: Bool = true, then finished: (() -> Void)? = nil) {
        guard let layer else {
            finished?()
            return
        }
        self.layer = nil
        layer.rootViewController.dismiss(animated: animated, completion: finished)
    }

    private func openAboveTabs(_ url: URL) {
        if let layer {
            layer.route(url)
            return
        }
        let navigator = Navigator(configuration: .init(name: "layer", startLocation: url))
        navigator.rootViewController.modalPresentationStyle = .fullScreen
        navigator.start()
        layer = navigator
        tabBarController?.present(navigator.rootViewController, animated: true)
    }

    private func show(tab: Int, visiting url: URL?) {
        guard let tabBarController else { return }
        tabBarController.selectedIndex = tab
        let navigator = tabBarController.activeNavigator
        navigator.clearAll()
        if let url { navigator.route(url) }
    }
}
