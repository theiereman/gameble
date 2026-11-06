import Foundation

struct TopBarState: Codable, Equatable {
    var standard = ""
    var special = ""
    var bell = ""
    var menuBadge = ""
    var avatar = ""
}

final class TopBarStore {
    static let shared = TopBarStore()

    private static let key = "top_bar_state"

    private(set) var state: TopBarState
    var onChange: ((TopBarState) -> Void)?

    private init() {
        let saved = UserDefaults.standard.data(forKey: Self.key)
        state = saved.flatMap { try? JSONDecoder().decode(TopBarState.self, from: $0) } ?? TopBarState()
    }

    func accept(_ report: TopBarState) {
        var next = report
        if next.avatar.isEmpty { next.avatar = state.avatar }
        guard next != state else { return }
        state = next
        UserDefaults.standard.set(try? JSONEncoder().encode(next), forKey: Self.key)
        onChange?(next)
    }

    func clear() {
        state = TopBarState()
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}

enum ScreenLabels {
    private static var labelsByURL: [URL: String] = [:]

    static func remember(_ label: String, for url: URL) {
        labelsByURL[url] = label
    }

    static func label(for url: URL) -> String? {
        labelsByURL[url]
    }
}
