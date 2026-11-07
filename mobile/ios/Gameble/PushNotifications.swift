import UIKit
import UserNotifications

final class PushNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotifications()

    var onOpen: ((String) -> Void)?

    private var pendingGrant: ((String?) -> Void)?

    func start() {
        UNUserNotificationCenter.current().delegate = self
    }

    func request(_ grant: @escaping (String?) -> Void) {
        pendingGrant = grant
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    self.finish(with: nil)
                }
            }
        }
    }

    func registered(deviceToken: Data) {
        finish(with: deviceToken.map { String(format: "%02x", $0) }.joined())
    }

    func failed() {
        finish(with: nil)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let path = response.notification.request.content.userInfo["path"] as? String {
            onOpen?(path)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    private func finish(with token: String?) {
        pendingGrant?(token)
        pendingGrant = nil
    }
}
