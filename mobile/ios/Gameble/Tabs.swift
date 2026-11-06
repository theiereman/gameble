import HotwireNative
import UIKit

enum Tabs {
    struct Destination {
        let tab: Int?
        let atRoot: Bool
    }

    private static let paths = ["", "/booster", "/library", "/friends", "/trades"]

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
            HotwireTab(title: Gameble.text("Friends", "Amis"), image: UIImage(named: "tab-friends"), url: Gameble.url("/friends")),
            HotwireTab(title: Gameble.text("Trades", "Échanges"), image: UIImage(named: "tab-trades"), url: Gameble.url("/trades"))
        ]
    }
}
