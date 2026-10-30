import Foundation

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
}
