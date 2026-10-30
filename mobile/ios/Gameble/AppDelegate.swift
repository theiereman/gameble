import HotwireNative
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Hotwire.config.applicationUserAgentPrefix = "Gameble iOS;"
        Hotwire.config.showDoneButtonOnModals = true
        Hotwire.loadPathConfiguration(from: [
            .file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!),
            .server(Gameble.rootURL.appending(path: "configurations/ios_v1.json"))
        ])
        Hotwire.registerBridgeComponents([
            SignInComponent.self,
            PushPermissionComponent.self,
            ShareComponent.self,
            HapticsComponent.self
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
