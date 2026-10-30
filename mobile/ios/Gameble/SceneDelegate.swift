import HotwireNative
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var tabBarController: HotwireTabBarController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.makeKeyAndVisible()
        reloadTabs()

        SignIn.shared.onSignedIn = { [weak self] in self?.reloadTabs() }
        PushNotifications.shared.onOpen = { [weak self] path in self?.open(path) }
    }

    func reloadTabs() {
        let tabBarController = HotwireTabBarController()
        tabBarController.load(Tabs.all)
        window?.rootViewController = tabBarController
        self.tabBarController = tabBarController
    }

    private func open(_ path: String) {
        guard let url = URL(string: path, relativeTo: Gameble.rootURL) else { return }
        tabBarController?.activeNavigator.route(url)
    }
}
