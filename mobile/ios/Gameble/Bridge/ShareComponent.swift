import HotwireNative
import UIKit

final class ShareComponent: BridgeComponent {
    override class var name: String { "share" }

    private var viewController: UIViewController? { delegate?.destination as? UIViewController }

    override func onReceive(message: Message) {
        guard message.event == "share", let data: MessageData = message.data(), let url = URL(string: data.url) else { return }

        let sheet = UIActivityViewController(activityItems: [data.text, url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = viewController?.view
        viewController?.present(sheet, animated: true)
    }

    private struct MessageData: Decodable {
        let url: String
        let text: String
    }
}
