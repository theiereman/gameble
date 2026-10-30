import HotwireNative

final class SignInComponent: BridgeComponent {
    override class var name: String { "sign-in" }

    override func onReceive(message: Message) {
        guard message.event == "start" else { return }
        SignIn.shared.start()
    }
}
