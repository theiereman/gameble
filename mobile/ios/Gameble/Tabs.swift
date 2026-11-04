import HotwireNative
import UIKit

enum Tabs {
    static var all: [HotwireTab] {
        [
            HotwireTab(title: label("Capsule", "Capsule"), image: UIImage(systemName: "sparkles.rectangle.stack")!, url: Gameble.url("/booster")),
            HotwireTab(title: label("Sets", "Sets"), image: UIImage(systemName: "square.grid.3x3")!, url: Gameble.url("/library")),
            HotwireTab(title: label("Social", "Social"), image: UIImage(systemName: "person.2")!, url: Gameble.url("/social")),
            HotwireTab(title: label("Me", "Moi"), image: UIImage(systemName: "person.crop.circle")!, url: Gameble.url("/me"))
        ]
    }

    private static func label(_ english: String, _ french: String) -> String {
        Gameble.locale == "fr" ? french : english
    }
}
