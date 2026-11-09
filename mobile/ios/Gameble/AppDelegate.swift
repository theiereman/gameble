import HotwireNative
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Hotwire.config.applicationUserAgentPrefix = "Gameble iOS;"
        Hotwire.config.defaultViewController = { GamebleWebViewController(url: $0) }
        Hotwire.config.defaultNavigationController = { GamebleNavigationController() }
        UITabBar.appearance().tintColor = Palette.accent
        UITabBar.appearance().unselectedItemTintColor = Palette.muted
        Hotwire.loadPathConfiguration(from: [
            .file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!),
            .server(Gameble.rootURL.appending(path: "configurations/ios_v1.json"))
        ])
        Hotwire.registerBridgeComponents([
            BackComponent.self,
            SignInComponent.self,
            PushPermissionComponent.self,
            ShareComponent.self,
            HapticsComponent.self,
            SheetComponent.self,
            PullToRefreshComponent.self,
            TopBarComponent.self
        ])
        PushNotifications.shared.start()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotifications.shared.registered(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotifications.shared.failed()
    }
}
