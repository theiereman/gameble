import HotwireNative
import UIKit

enum Tabs {
    struct Destination {
        let tab: Int?
        let atRoot: Bool
    }

    private static let paths = ["", "/booster", "/library", "/trades", "/market"]
    private static let capsule = 1
    private static let trades = 3

    static func destination(of path: String) -> Destination {
        let location = path.replacingOccurrences(of: #"^/(en|fr)(?=[/?#]|$)"#, with: "", options: .regularExpression)
        let bare = String(location.prefix { $0 != "?" && $0 != "#" }).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let tab = paths.firstIndex { tabPath in
            let tabBare = String(tabPath.dropFirst())
            return bare == tabBare || (!tabBare.isEmpty && bare.hasPrefix("\(tabBare)/"))
        }
        let atRoot = tab.map { location.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == String(paths[$0].dropFirst()) } ?? false
        return Destination(tab: tab, atRoot: atRoot)
    }

    static var all: [HotwireTab] {
        [
            HotwireTab(title: Gameble.text("Bridge", "Pont"), image: UIImage(named: "tab-hub"), url: Gameble.url("")),
            HotwireTab(title: Gameble.text("Capsule", "Capsule"), image: UIImage(named: "tab-capsule"), url: Gameble.url("/booster")),
            HotwireTab(title: Gameble.text("Sets", "Sets"), image: UIImage(named: "tab-sets"), url: Gameble.url("/library")),
            HotwireTab(title: Gameble.text("Trades", "Échanges"), image: UIImage(named: "tab-trades"), url: Gameble.url("/trades")),
            HotwireTab(title: Gameble.text("Market", "Marché"), image: UIImage(named: "tab-market"), url: Gameble.url("/market"))
        ]
    }

    static func showBadges(of state: TopBarState, on tabBar: UITabBar) {
        badge(state.capsules, on: tabBar, at: capsule, color: Palette.primary, text: Palette.onPrimary)
        badge(state.trades, on: tabBar, at: trades, color: Palette.alert, text: Palette.onAlert)
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
