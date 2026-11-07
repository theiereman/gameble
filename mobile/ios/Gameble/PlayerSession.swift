import Foundation

enum PlayerSession {
    private static let signedInKey = "signed_in"

    static var probablySignedIn: Bool {
        UserDefaults.standard.bool(forKey: signedInKey)
    }

    static func signedIn() {
        UserDefaults.standard.set(true, forKey: signedInKey)
    }

    static func signedOut() {
        UserDefaults.standard.set(false, forKey: signedInKey)
    }
}
