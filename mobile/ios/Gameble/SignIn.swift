import AuthenticationServices
import UIKit
import WebKit

// Google refuses OAuth inside a web view, so the sign-in runs in the system browser and hands a ticket back.
final class SignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = SignIn()

    var onSignedIn: (() -> Void)?

    private var session: ASWebAuthenticationSession?

    func start() {
        guard session == nil else { return }

        let state = Self.randomState()
        let url = Gameble.url("/native/sign-in/\(state)")
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: Gameble.callbackScheme) { [weak self] callback, _ in
            self?.session = nil
            guard let ticket = callback.flatMap(Self.ticket(in:)) else { return }
            self?.redeem(ticket: ticket, state: state)
        }
        session.presentationContextProvider = self
        self.session = session
        session.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }

    private func redeem(ticket: String, state: String) {
        let url = Gameble.url("/native/session")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(Gameble.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = Self.form(["ticket": ticket, "state": state])
        request.httpShouldHandleCookies = false

        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            guard let response = response as? HTTPURLResponse, response.statusCode == 204 else { return }

            let headers = response.allHeaderFields.reduce(into: [String: String]()) { fields, field in
                if let name = field.key as? String, let value = field.value as? String { fields[name] = value }
            }
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
            DispatchQueue.main.async { self?.store(cookies) }
        }.resume()
    }

    private func store(_ cookies: [HTTPCookie]) {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let group = DispatchGroup()
        cookies.forEach { cookie in
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { [weak self] in self?.onSignedIn?() }
    }

    private static func ticket(in callback: URL) -> String? {
        URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "ticket" }?.value
    }

    private static func randomState() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func form(_ fields: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
    }
}
