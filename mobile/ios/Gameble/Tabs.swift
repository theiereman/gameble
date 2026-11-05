import HotwireNative
import UIKit

enum Tabs {
    static var all: [HotwireTab] {
        [
            HotwireTab(title: label("Bridge", "Pont"), image: UIImage(systemName: "circle.grid.cross")!, url: Gameble.url("")),
            HotwireTab(title: label("Capsule", "Capsule"), image: UIImage(systemName: "sparkles.rectangle.stack")!, url: Gameble.url("/booster")),
            HotwireTab(title: label("Sets", "Sets"), image: UIImage(systemName: "square.grid.3x3")!, url: Gameble.url("/library")),
            HotwireTab(title: label("Friends", "Amis"), image: UIImage(systemName: "person.2")!, url: Gameble.url("/friends")),
            HotwireTab(title: label("Trades", "Échanges"), image: UIImage(systemName: "arrow.left.arrow.right")!, url: Gameble.url("/trades"))
        ]
    }

    private static func label(_ english: String, _ french: String) -> String {
        Gameble.locale == "fr" ? french : english
    }
}
