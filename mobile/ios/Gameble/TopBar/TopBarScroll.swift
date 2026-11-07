import CoreGraphics

struct TopBarScroll {
    private static let alwaysShownAbove: CGFloat = 16
    private static let margin: CGFloat = 4

    private var anchor: CGFloat = 0

    mutating func reset(at position: CGFloat) {
        anchor = position
    }

    mutating func barShownAfterMoving(to position: CGFloat, furthest: CGFloat) -> Bool? {
        let bouncing = position < 0 || position > max(furthest, 0)
        guard !bouncing else { return nil }
        if position < Self.alwaysShownAbove {
            anchor = position
            return true
        }
        if position > anchor + Self.margin {
            anchor = position
            return false
        }
        if position < anchor - Self.margin {
            anchor = position
            return true
        }
        return nil
    }
}
