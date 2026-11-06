import HotwireNative
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var tabBarController: HotwireTabBarController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.backgroundColor = Palette.ground
        window?.makeKeyAndVisible()

        SignIn.shared.onSignedIn = { [weak self] in
            PlayerSession.signedIn()
            self?.reloadTabs()
        }
        SignIn.shared.onSignInNeeded = { [weak self] in self?.showSignIn() }
        PushNotifications.shared.onOpen = { [weak self] path in self?.open(path) }

        if PlayerSession.probablySignedIn {
            reloadTabs()
        } else {
            showSignIn()
        }
    }

    func reloadTabs() {
        let tabBarController = HotwireTabBarController()
        tabBarController.load(Tabs.all)
        window?.rootViewController = tabBarController
        self.tabBarController = tabBarController
        TopBarNavigation.shared.tabBarController = tabBarController
    }

    private func showSignIn() {
        PlayerSession.signedOut()
        guard !(window?.rootViewController is SignInViewController) else { return }
        TopBarNavigation.shared.closeLayer(animated: false)
        tabBarController = nil
        window?.rootViewController = SignInViewController()
    }

    private func open(_ path: String) {
        guard let url = URL(string: path, relativeTo: Gameble.rootURL) else { return }
        tabBarController?.activeNavigator.route(url)
    }
}
