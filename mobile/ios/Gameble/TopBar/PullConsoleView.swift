import UIKit

final class PullConsoleView: UIView {
    enum Phase: Equatable {
        case pulling(CGFloat)
        case refreshing(since: CFTimeInterval)
        case done(took: CFTimeInterval)
    }

    static let size = CGSize(width: 306, height: 64)

    private static let segmentCount = 24
    private static let cometLength = 6
    private static let packetCount = 5
    private static let packetInterval: CFTimeInterval = 0.32
    private static let cometStep: CFTimeInterval = 0.045
    private static let blinkInterval: CFTimeInterval = 0.42
    private static let pulseDuration: CFTimeInterval = 0.35
    private static let bracket: CGFloat = 3

    private var phase = Phase.pulling(0)
    private var pulseStart: CFTimeInterval?
    private var ticker: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        alpha = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize { Self.size }

    func show(_ newPhase: Phase) {
        if case .pulling(let progress) = newPhase, progress >= 1, !phaseIsFull { pulseStart = CACurrentMediaTime() }
        phase = newPhase
        let animating = pulseStart != nil || { if case .refreshing = newPhase { return true } else { return false } }()
        animating ? startTicking() : stopTicking()
        setNeedsDisplay()
    }

    private var phaseIsFull: Bool {
        if case .pulling(let progress) = phase { return progress >= 1 }
        return false
    }

    private func startTicking() {
        guard ticker == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        ticker = link
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    @objc private func tick() {
        if let start = pulseStart, CACurrentMediaTime() - start > Self.pulseDuration {
            pulseStart = nil
            if case .pulling = phase { stopTicking() }
        }
        setNeedsDisplay()
    }

    override func removeFromSuperview() {
        stopTicking()
        super.removeFromSuperview()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let now = CACurrentMediaTime()
        let panel = bounds.insetBy(dx: Self.bracket, dy: Self.bracket)
        drawFrame(panel, in: context, now: now)
        let inner = panel.insetBy(dx: 10, dy: 0)
        let readout = Readout(phase: phase, now: now)
        drawRow(left: Gameble.text("▸ SYNC", "▸ SYNCHRO"), leftColor: Palette.accent,
                right: readout.value, rightColor: readout.valueColor,
                size: 9.5, bold: true, top: panel.minY + 7, in: inner)
        drawSegments(readout.segmentColors(count: Self.segmentCount, now: now), in: CGRect(x: inner.minX, y: panel.minY + 24, width: inner.width, height: 8), context: context)
        let cursorShown = readout.blinks && Int(now / Self.blinkInterval) % 2 == 0
        drawRow(left: readout.message, leftColor: readout.messageColor, right: readout.aux, rightColor: Palette.dim,
                size: 8.5, bold: false, top: panel.minY + 39, in: inner, cursor: cursorShown)
    }

    private func drawFrame(_ panel: CGRect, in context: CGContext, now: CFTimeInterval) {
        let pulsing = pulseStart.map { now - $0 < Self.pulseDuration } ?? false
        let golden = pulsing || phaseIsFull || { if case .done = phase { return true } else { return false } }()
        Palette.outline.setFill()
        context.fill(panel.insetBy(dx: -2, dy: -2))
        Palette.sunken.setFill()
        context.fill(panel)
        UIColor.white.withAlphaComponent(0.025).setFill()
        stride(from: panel.minY + 2, to: panel.maxY, by: 3).forEach { context.fill(CGRect(x: panel.minX, y: $0, width: panel.width, height: 1)) }
        (pulsing ? Palette.gold : Palette.line).setStroke()
        context.setLineWidth(1)
        context.stroke(panel.insetBy(dx: 0.5, dy: 0.5))
        (golden ? Palette.gold : Palette.accent).setFill()
        let arm: CGFloat = 5, thickness: CGFloat = 2, outer = bounds
        for corner in [CGPoint(x: outer.minX, y: outer.minY), CGPoint(x: outer.maxX - arm, y: outer.minY),
                       CGPoint(x: outer.minX, y: outer.maxY - arm), CGPoint(x: outer.maxX - arm, y: outer.maxY - arm)] {
            let onLeft = corner.x == outer.minX, onTop = corner.y == outer.minY
            context.fill(CGRect(x: corner.x, y: onTop ? corner.y : outer.maxY - thickness, width: arm, height: thickness))
            context.fill(CGRect(x: onLeft ? corner.x : outer.maxX - thickness, y: corner.y, width: thickness, height: arm))
        }
    }

    private func drawSegments(_ colors: [UIColor], in strip: CGRect, context: CGContext) {
        let gap: CGFloat = 2
        let width = (strip.width - gap * CGFloat(colors.count - 1)) / CGFloat(colors.count)
        for (index, color) in colors.enumerated() {
            color.setFill()
            context.fill(CGRect(x: strip.minX + CGFloat(index) * (width + gap), y: strip.minY, width: width, height: strip.height).integral)
        }
    }

    private func drawRow(left: String, leftColor: UIColor, right: String, rightColor: UIColor,
                         size: CGFloat, bold: Bool, top: CGFloat, in row: CGRect, cursor: Bool = false) {
        let font = bold ? Typeface.bold(size) : Typeface.regular(size)
        let leftText = NSAttributedString(string: left, attributes: [.font: font, .foregroundColor: leftColor, .kern: size * 0.14])
        leftText.draw(at: CGPoint(x: row.minX, y: top))
        if cursor {
            leftColor.setFill()
            UIRectFill(CGRect(x: row.minX + leftText.size().width + 3, y: top + 1, width: 6, height: size + 0.5))
        }
        let rightText = NSAttributedString(string: right, attributes: [.font: font, .foregroundColor: rightColor, .kern: size * 0.1])
        rightText.draw(at: CGPoint(x: row.maxX - rightText.size().width, y: top))
    }

    private struct Readout {
        let phase: Phase
        let now: CFTimeInterval

        var value: String {
            switch phase {
            case .pulling(let progress): String(Int((progress * 100).rounded())).leftPadded(to: 3) + "%"
            case .refreshing(let since): String(format: "%.2fs", now - since)
            case .done: "100%"
            }
        }

        var valueColor: UIColor {
            switch phase {
            case .pulling(let progress): progress >= 1 ? Palette.gold : Palette.accent
            case .refreshing: Palette.lime
            case .done: Palette.gold
            }
        }

        var message: String {
            switch phase {
            case .pulling(let progress) where progress >= 1: Gameble.text("RELEASE ▸ SYNC", "RELÂCHER ▸ SYNCHRONISER")
            case .pulling: Gameble.text("PULL TO SYNC", "TIRER POUR SYNCHRONISER")
            case .refreshing(let since):
                Gameble.text("SYNC · PACKET \(packet(since))/\(PullConsoleView.packetCount)", "SYNC · PAQUET \(packet(since))/\(PullConsoleView.packetCount)")
            case .done: Gameble.text("OK · SCREEN UP TO DATE", "OK · ÉCRAN À JOUR")
            }
        }

        var messageColor: UIColor {
            switch phase {
            case .pulling(let progress): progress >= 1 ? Palette.gold : Palette.dim
            case .refreshing: Palette.lime
            case .done: Palette.gold
            }
        }

        var aux: String {
            let distance = Int(PullGesture.distance)
            switch phase {
            case .pulling(let progress) where progress >= 1: return Gameble.text("threshold \(distance)pt", "seuil \(distance)pt")
            case .pulling(let progress): return "\(Int((progress * PullGesture.distance).rounded()))/\(distance)pt"
            case .refreshing: return Gameble.text("▒ network", "▒ réseau")
            case .done(let took): return String(format: "%.2fs", took)
            }
        }

        var blinks: Bool {
            switch phase {
            case .pulling(let progress): progress >= 1
            case .refreshing: true
            case .done: false
            }
        }

        func segmentColors(count: Int, now: CFTimeInterval) -> [UIColor] {
            switch phase {
            case .pulling(let progress):
                let lit = Int((progress * CGFloat(count)).rounded())
                let color = progress >= 1 ? Palette.gold : Palette.lime
                return (0..<count).map { $0 < lit ? color : Palette.raised }
            case .refreshing:
                if UIAccessibility.isReduceMotionEnabled { return Array(repeating: Palette.lime, count: count) }
                let head = Int(now / PullConsoleView.cometStep) % (count + PullConsoleView.cometLength)
                return (0..<count).map { index in
                    let behind = head - index
                    guard behind >= 0, behind < PullConsoleView.cometLength else { return Palette.raised }
                    return behind == 0 ? Palette.limeGlow : Palette.lime.withAlphaComponent(1 - CGFloat(behind) / CGFloat(PullConsoleView.cometLength))
                }
            case .done:
                return Array(repeating: Palette.gold, count: count)
            }
        }

        private func packet(_ since: CFTimeInterval) -> Int {
            min(PullConsoleView.packetCount, 1 + Int((now - since) / PullConsoleView.packetInterval))
        }
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        String(repeating: "0", count: max(0, length - count)) + self
    }
}
