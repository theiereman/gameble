import HotwireNative
import UIKit

final class PullToRefreshComponent: BridgeComponent {
    override class var name: String { "pull-to-refresh" }

    override func onReceive(message: Message) {
        guard let screen = delegate?.destination as? GamebleWebViewController else { return }
        switch message.event {
        case "hold": screen.holdPullToRefresh()
        case "release": screen.releasePullToRefresh()
        default: break
        }
    }
}
