import HotwireNative
import UIKit

final class TopBarComponent: BridgeComponent {
    override class var name: String { "top-bar" }

    override func onReceive(message: Message) {
        switch message.event {
        case "navigate":
            guard let destination: Destination = message.data() else { return }
            TopBarNavigation.shared.open(destination.path)
        case "state":
            guard let screen = delegate?.destination as? UIViewController,
                  TopBarNavigation.shared.isOnView(screen),
                  let report: TopBarState = message.data() else { return }
            TopBarStore.shared.accept(report)
        case "dialog":
            guard let dialog: DialogState = message.data() else { return }
            (delegate?.destination as? GamebleWebViewController)?.dialogChanged(open: dialog.open)
        default:
            break
        }
    }

    private struct Destination: Decodable {
        let path: String
    }

    private struct DialogState: Decodable {
        let open: Bool
    }
}
