import HotwireNative
import UIKit

final class BackComponent: BridgeComponent {
    override class var name: String { "back" }

    override func onReceive(message: Message) {
        guard let viewController = delegate?.destination as? UIViewController else { return }
        switch message.event {
        case "connect":
            let canGoBack = (viewController.navigationController?.viewControllers.count ?? 1) > 1
            reply(to: "connect", with: Reply(canGoBack: canGoBack))
        case "back":
            viewController.navigationController?.popViewController(animated: true)
        default:
            break
        }
    }

    private struct Reply: Encodable {
        let canGoBack: Bool
    }
}
