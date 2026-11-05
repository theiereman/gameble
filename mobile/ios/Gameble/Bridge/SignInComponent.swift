import HotwireNative
import UIKit

final class SignInComponent: BridgeComponent {
    override class var name: String { "sign-in" }

    override func onReceive(message: Message) {
        switch message.event {
        case "shown":
            viewController?.tabBarController?.tabBar.isHidden = true
        case "start":
            SignIn.shared.start()
        default:
            break
        }
    }

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }
}
