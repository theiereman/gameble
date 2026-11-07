import HotwireNative
import UIKit

final class TabRouting: NavigatorDelegate {
    static let shared = TabRouting()

    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        guard !navigator.rootViewController.viewControllers.isEmpty,
              let path = Self.path(of: proposal.url),
              let tab = Tabs.destination(of: path).tab,
              tab != tabIndex(of: navigator) else { return .accept }
        DispatchQueue.main.async {
            navigator.rootViewController.presentedViewController?.dismiss(animated: true)
            TopBarNavigation.shared.open(path)
        }
        return .reject
    }

    private func tabIndex(of navigator: Navigator) -> Int? {
        guard let tabs = TopBarNavigation.shared.shell?.tabs, navigator === tabs.activeNavigator else { return nil }
        return tabs.selectedIndex
    }

    private static func path(of url: URL) -> String? {
        guard url.host == Gameble.rootURL.host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
        return components.percentEncodedPath + (components.percentEncodedQuery.map { "?\($0)" } ?? "")
    }
}
