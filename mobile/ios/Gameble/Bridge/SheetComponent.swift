import HotwireNative
import UIKit

final class SheetComponent: BridgeComponent {
    override class var name: String { "sheet" }

    override func onReceive(message: Message) {
        guard let viewController = delegate?.destination as? UIViewController else { return }
        switch message.event {
        case "close":
            viewController.dismiss(animated: true)
        default:
            viewController.tabBarController?.tabBar.isHidden = message.event == "shown"
        }
    }
}
