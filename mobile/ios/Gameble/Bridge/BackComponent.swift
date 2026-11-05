import HotwireNative
import UIKit

final class BackComponent: BridgeComponent {
    override class var name: String { "back" }

    private static var screenLabels: [URL: String] = [:]

    override func onReceive(message: Message) {
        guard let viewController = delegate?.destination as? UIViewController else { return }
        switch message.event {
        case "screen":
            if let url = (viewController as? Visitable)?.currentVisitableURL, let data: ScreenData = message.data() {
                Self.screenLabels[url] = data.label
            }
        case "connect":
            connect(from: viewController)
        case "back":
            viewController.navigationController?.popViewController(animated: true)
        default:
            break
        }
    }

    private func connect(from viewController: UIViewController) {
        let stack = viewController.navigationController?.viewControllers ?? []
        let previous = stack.count > 1 ? stack[stack.count - 2] as? Visitable : nil
        let previousLabel = previous.flatMap { Self.screenLabels[$0.currentVisitableURL] }
        reply(to: "connect", with: Reply(canGoBack: stack.count > 1, previousLabel: previousLabel))
    }

    private struct ScreenData: Decodable {
        let label: String
    }

    private struct Reply: Encodable {
        let canGoBack: Bool
        let previousLabel: String?
    }
}
