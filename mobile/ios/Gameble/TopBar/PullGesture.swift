import CoreGraphics

struct PullGesture {
    enum Change: Equatable {
        case pulled(CGFloat, reachedFull: Bool)
        case letGo(refresh: Bool)
    }

    static let distance: CGFloat = 80

    private var progress: CGFloat = 0
    private var tracking = false

    mutating func moved(to offset: CGFloat, tracking isTracking: Bool) -> Change? {
        guard isTracking else { return letGo() }
        tracking = true
        let previous = progress
        progress = max(0, -offset) / Self.distance
        guard progress > 0 || previous > 0 else { return nil }
        return .pulled(min(1, progress), reachedFull: progress >= 1 && previous < 1)
    }

    mutating func cancel() -> Change? {
        guard tracking else { return nil }
        tracking = false
        progress = 0
        return .letGo(refresh: false)
    }

    private mutating func letGo() -> Change? {
        guard tracking else { return nil }
        let refresh = progress >= 1
        tracking = false
        progress = 0
        return .letGo(refresh: refresh)
    }
}
