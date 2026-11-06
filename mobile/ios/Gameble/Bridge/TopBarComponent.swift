import HotwireNative

final class TopBarComponent: BridgeComponent {
    override class var name: String { "top-bar" }

    override func onReceive(message: Message) {
        guard message.event == "navigate", let destination: Destination = message.data() else { return }
        TopBarNavigation.shared.open(destination.path)
    }

    private struct Destination: Decodable {
        let path: String
    }
}
