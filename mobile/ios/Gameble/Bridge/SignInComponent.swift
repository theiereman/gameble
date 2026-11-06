import HotwireNative
import UIKit

final class SignInComponent: BridgeComponent {
    override class var name: String { "sign-in" }

    override func onReceive(message: Message) {
        switch message.event {
        case "shown":
            DispatchQueue.main.async { SignIn.shared.onSignInNeeded?() }
        case "start":
            SignIn.shared.start()
        default:
            break
        }
    }
}
