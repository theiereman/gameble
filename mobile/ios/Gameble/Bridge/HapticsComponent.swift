import HotwireNative
import UIKit

final class HapticsComponent: BridgeComponent {
    override class var name: String { "haptics" }

    override func onReceive(message: Message) {
        guard message.event == "impact", let data: MessageData = message.data() else { return }

        let generator = UIImpactFeedbackGenerator(style: Self.styles[data.style] ?? .light)
        generator.impactOccurred()
    }

    private static let styles: [String: UIImpactFeedbackGenerator.FeedbackStyle] = ["light": .light, "medium": .medium, "heavy": .heavy]

    private struct MessageData: Decodable {
        let style: String
    }
}
