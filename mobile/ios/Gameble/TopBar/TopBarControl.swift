import UIKit

final class TopBarControl: UIControl {
    static let height: CGFloat = 40

    private static let touchSide: CGFloat = 44

    private let badge = UILabel()

    init(background: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = background
        layer.borderWidth = 2
        layer.borderColor = Palette.controlBorder.cgColor
        heightAnchor.constraint(equalToConstant: Self.height).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let wider = max(0, Self.touchSide - bounds.width) / 2
        let taller = max(0, Self.touchSide - bounds.height) / 2
        return bounds.insetBy(dx: -wider, dy: -taller).contains(point)
    }

    func addBadge() {
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.font = Typeface.bold(11)
        badge.textColor = Palette.onAlert
        badge.backgroundColor = Palette.alert
        badge.textAlignment = .center
        badge.isHidden = true
        addSubview(badge)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: topAnchor, constant: -6),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 6),
            badge.heightAnchor.constraint(equalToConstant: 17),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 17)
        ])
    }

    func showBadge(_ text: String) {
        badge.text = text.isEmpty ? nil : " \(text) "
        badge.isHidden = text.isEmpty
    }

    func embed(_ content: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        content.isUserInteractionEnabled = false
        insertSubview(content, at: 0)
    }
}
