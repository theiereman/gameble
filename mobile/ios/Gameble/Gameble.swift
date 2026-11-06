import UIKit

enum Gameble {
    static let rootURL: URL = {
        let configured = Bundle.main.object(forInfoDictionaryKey: "GamebleRootURL") as? String
        return URL(string: configured ?? "https://gameble.net")!
    }()

    static let callbackScheme = "gameble"

    static let userAgent = "Gameble iOS; Hotwire Native iOS; Turbo Native iOS"

    static var locale: String {
        Locale.preferredLanguages.first?.hasPrefix("fr") == true ? "fr" : "en"
    }

    static func url(_ path: String) -> URL {
        rootURL.appending(path: "\(locale)\(path)")
    }

    static func text(_ english: String, _ french: String) -> String {
        locale == "fr" ? french : english
    }
}

enum Palette {
    static let ground = UIColor(hex: 0x0B0F15)
    static let panel = UIColor(hex: 0x121A24)
    static let primary = UIColor(hex: 0x7AA60A)
    static let primaryPressed = UIColor(hex: 0x5F8108)
    static let primaryShade = UIColor(hex: 0x4A6506)
    static let onPrimary = UIColor(hex: 0x0F1A03)
    static let dim = UIColor(hex: 0x5D6B78)
    static let accent = UIColor(hex: 0x66C0F4)
    static let muted = UIColor(hex: 0x8F98A0)
    static let steamBar = UIColor(hex: 0x171A21)
    static let line = UIColor(hex: 0x2A475E)
    static let raised = UIColor(hex: 0x1B2838)
    static let sunken = UIColor(hex: 0x0E141B)
    static let controlBorder = UIColor(hex: 0x2A6F9A)
    static let alert = UIColor(hex: 0xE8833A)
    static let onAlert = UIColor(hex: 0x1D0F03)
    static let friends = UIColor(hex: 0x8AA0FF)
    static let onFriends = UIColor(hex: 0x06090D)
}

enum Typeface {
    static func regular(_ size: CGFloat) -> UIFont {
        UIFont(name: "JetBrainsMono-Regular", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func bold(_ size: CGFloat) -> UIFont {
        UIFont(name: "JetBrainsMono-Bold", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .bold)
    }
}

private extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
