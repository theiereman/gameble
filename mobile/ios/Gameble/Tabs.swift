import HotwireNative
import UIKit

enum Tabs {
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
