import UIKit

final class PullConsoleView: UIView {
    private static let cellCount = 5
    private static let sweepInterval: TimeInterval = 0.11

    private let cells: [UIView] = (0..<PullConsoleView.cellCount).map { _ in UIView() }
    private let label = UILabel()
    private var sweep: Timer?
    private var sweepStep = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        backgroundColor = Palette.outline
        layer.borderColor = Palette.line.cgColor
        layer.borderWidth = 2
        alpha = 0

        let row = UIStackView(arrangedSubviews: cells + [label])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 3
        row.setCustomSpacing(8, after: cells[cells.count - 1])
        addSubview(row)
        cells.forEach { cell in
            cell.translatesAutoresizingMaskIntoConstraints = false
            cell.layer.borderWidth = 1.5
            NSLayoutConstraint.activate([
                cell.widthAnchor.constraint(equalToConstant: 8),
                cell.heightAnchor.constraint(equalToConstant: 13)
            ])
        }
        label.font = Typeface.bold(13)
        label.textAlignment = .center
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 38),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        show(progress: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(progress: CGFloat) {
        stopSweep()
        let full = progress >= 1
        let lit = full ? Self.cellCount : Int(progress * CGFloat(Self.cellCount))
        light(cellsAt: Set(0..<lit), in: full ? Palette.gold : Palette.lime)
        write(full ? "OK" : "..", in: full ? Palette.gold : Palette.lime)
        alpha = min(1, progress * 1.4)
        let scale = 0.6 + 0.4 * min(1, progress)
        transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    func startSweep() {
        alpha = 1
        transform = .identity
        write("SYNC", in: Palette.lime)
        sweepStep = 0
        stepSweep()
        sweep?.invalidate()
        sweep = Timer.scheduledTimer(withTimeInterval: UIAccessibility.isReduceMotionEnabled ? 0.4 : Self.sweepInterval, repeats: true) { [weak self] _ in
            self?.stepSweep()
        }
    }

    func hide() {
        stopSweep()
        UIView.animate(withDuration: 0.2) { self.alpha = 0 }
    }

    private func stepSweep() {
        light(cellsAt: [sweepStep % Self.cellCount], in: Palette.lime)
        sweepStep += 1
    }

    private func stopSweep() {
        sweep?.invalidate()
        sweep = nil
    }

    private func light(cellsAt lit: Set<Int>, in color: UIColor) {
        for (index, cell) in cells.enumerated() {
            cell.layer.borderColor = color.cgColor
            cell.backgroundColor = lit.contains(index) ? color : .clear
        }
    }

    private func write(_ text: String, in color: UIColor) {
        label.text = text
        label.textColor = color
    }
}
