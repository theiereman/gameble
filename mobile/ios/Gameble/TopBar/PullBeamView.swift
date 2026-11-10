import UIKit

final class PullBeamView: UIView {
    enum Phase: Equatable {
        case pulling(CGFloat)
        case refreshing
    }

    static let height: CGFloat = 4

    private static let cometWidth: CGFloat = 90
    private static let sweepDuration: CFTimeInterval = 0.9
    private static let fadeDuration: TimeInterval = 0.25

    private var phase = Phase.pulling(0)
    private var ticker: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        layer.shadowColor = Palette.gold.cgColor
        layer.shadowOffset = .zero
        layer.shadowRadius = 6
        alpha = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ newPhase: Phase) {
        phase = newPhase
        switch newPhase {
        case .pulling(let progress):
            stopSweeping()
            layer.removeAllAnimations()
            alpha = progress > 0 ? 1 : 0
            layer.shadowOpacity = progress >= 1 ? 0.9 : 0
        case .refreshing:
            alpha = 1
            layer.shadowOpacity = 0
            if !UIAccessibility.isReduceMotionEnabled { startSweeping() }
        }
        setNeedsDisplay()
    }

    func fadeOut() {
        UIView.animate(withDuration: Self.fadeDuration, delay: 0, options: [.beginFromCurrentState], animations: { self.alpha = 0 }) { [weak self] finished in
            guard finished else { return }
            self?.show(.pulling(0))
        }
    }

    private func startSweeping() {
        guard ticker == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(sweep))
        link.add(to: .main, forMode: .common)
        ticker = link
    }

    private func stopSweeping() {
        ticker?.invalidate()
        ticker = nil
    }

    @objc private func sweep() {
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        switch phase {
        case .pulling(let progress) where progress >= 1:
            Palette.gold.setFill()
            context.fill(bounds)
        case .pulling(let progress):
            Palette.sunken.setFill()
            context.fill(bounds)
            let reach = bounds.width / 2 * progress
            Palette.lime.setFill()
            context.fill(CGRect(x: 0, y: 0, width: reach, height: bounds.height))
            context.fill(CGRect(x: bounds.width - reach, y: 0, width: reach, height: bounds.height))
        case .refreshing:
            Palette.limeTrack.setFill()
            context.fill(bounds)
            drawComet(in: context)
        }
    }

    private func drawComet(in context: CGContext) {
        let travel = bounds.width + Self.cometWidth * 2
        let elapsed = UIAccessibility.isReduceMotionEnabled ? 0.5 : CACurrentMediaTime().truncatingRemainder(dividingBy: Self.sweepDuration) / Self.sweepDuration
        let head = CGFloat(elapsed) * travel - Self.cometWidth
        let colors = [Palette.lime.withAlphaComponent(0).cgColor, Palette.lime.cgColor, Palette.limeGlow.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.7, 1]) else { return }
        context.saveGState()
        context.clip(to: CGRect(x: head - Self.cometWidth, y: 0, width: Self.cometWidth, height: bounds.height))
        context.drawLinearGradient(gradient, start: CGPoint(x: head - Self.cometWidth, y: 0), end: CGPoint(x: head, y: 0), options: [])
        context.restoreGState()
    }
}
