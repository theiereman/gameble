import HotwireNative

final class BackComponent: BridgeComponent {
    override class var name: String { "back" }

    override func onReceive(message: Message) {
        guard message.event == "screen",
              let screen = delegate?.destination as? Visitable,
              let data: ScreenData = message.data() else { return }
        ScreenLabels.remember(data.label, for: screen.currentVisitableURL)
        TopBarNavigation.shared.shell?.refreshLeftSide()
    }

    private struct ScreenData: Decodable {
        let label: String
    }
}
