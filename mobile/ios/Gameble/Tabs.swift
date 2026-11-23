import HotwireNative
import UIKit

enum Tabs {
    struct Destination {
        let tab: Int?
        let atRoot: Bool
    }

    private static let paths = ["", "/booster", "/library", "/exchanges", "/duels"]
    private static let roots = [[""], ["/booster"], ["/library"], ["/exchanges", "/trades", "/market"], ["/duels"]]
    private static let capsule = 1
    private static let trades = 3
    private static let duels = 4
    private static let alpha = "ALPHA"

    static func destination(of path: String) -> Destination {
        let location = path.replacingOccurrences(of: #"^/(en|fr)(?=[/?#]|$)"#, with: "", options: .regularExpression)
        let bare = String(location.prefix { $0 != "?" && $0 != "#" }).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let tab = roots.firstIndex { tabRoots in
            tabRoots.contains { root in
                let rootBare = String(root.dropFirst())
                return bare == rootBare || (!rootBare.isEmpty && bare.hasPrefix("\(rootBare)/"))
            }
        }
        let atRoot = tab.map { location.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == String(paths[$0].dropFirst()) } ?? false
        return Destination(tab: tab, atRoot: atRoot)
    }

    static var all: [HotwireTab] {
        [
            HotwireTab(title: Gameble.text("Bridge", "Pont"), image: UIImage(named: "tab-hub"), url: Gameble.url("")),
            HotwireTab(title: Gameble.text("Capsule", "Capsule"), image: UIImage(named: "tab-capsule"), url: Gameble.url("/booster")),
            HotwireTab(title: Gameble.text("Sets", "Sets"), image: UIImage(named: "tab-sets"), url: Gameble.url("/library")),
            HotwireTab(title: Gameble.text("Trade", "Commerce"), image: UIImage(named: "tab-trades"), url: Gameble.url("/exchanges")),
            HotwireTab(title: Gameble.text("Duels", "Duels"), image: UIImage(named: "tab-duels"), url: Gameble.url("/duels"))
        ]
    }

    static func showBadges(of state: TopBarState, on tabBar: UITabBar) {
        badge(state.capsules, on: tabBar, at: capsule, color: Palette.primary, text: Palette.onPrimary)
        badge(state.trades, on: tabBar, at: trades, color: Palette.alert, text: Palette.onAlert)
        if state.duels.isEmpty {
            badge(alpha, on: tabBar, at: duels, color: Palette.gold, text: Palette.onGold)
        } else {
            badge(state.duels, on: tabBar, at: duels, color: Palette.accent, text: Palette.onAccent)
        }
    }

    private static func badge(_ value: String, on tabBar: UITabBar, at index: Int, color: UIColor, text: UIColor) {
        guard let item = tabBar.items?[safe: index] else { return }
        item.badgeColor = color
        item.setBadgeTextAttributes([.foregroundColor: text, .font: Typeface.bold(11)], for: .normal)
        item.badgeValue = value.isEmpty ? nil : value
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
