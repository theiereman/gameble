import HotwireNative

final class PushPermissionComponent: BridgeComponent {
    override class var name: String { "push-permission" }

    override func onReceive(message: Message) {
        guard message.event == "request" else { return }

        PushNotifications.shared.request { [weak self] token in
            if let token {
                self?.reply(to: "request", with: Grant(token: token, platform: "apple"))
            } else {
                self?.reply(to: "request", with: Refusal())
            }
        }
    }

    private struct Grant: Encodable {
        let token: String
        let platform: String
    }

    private struct Refusal: Encodable {
        let granted = false
    }
}
