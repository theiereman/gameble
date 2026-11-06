import HotwireNative
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var shell: ShellViewController?

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
        let tabs = HotwireTabBarController(navigatorDelegate: TabRouting.shared)
        tabs.load(Tabs.all)
        let shell = ShellViewController(tabs: tabs)
        self.shell = shell
        TopBarNavigation.shared.shell = shell
        window?.rootViewController = shell
    }

    private func showSignIn() {
        PlayerSession.signedOut()
        TopBarStore.shared.clear()
        guard !(window?.rootViewController is SignInViewController) else { return }
        TopBarNavigation.shared.closeLayer(animated: false)
        shell = nil
        window?.rootViewController = SignInViewController()
    }

    private func open(_ path: String) {
        guard let url = URL(string: path, relativeTo: Gameble.rootURL) else { return }
        TopBarNavigation.shared.closeLayer(animated: false) { [weak self] in
            self?.shell?.tabs.activeNavigator.route(url)
        }
    }
}
