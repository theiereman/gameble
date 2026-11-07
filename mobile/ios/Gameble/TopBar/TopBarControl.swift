import UIKit

private final class BadgeLabel: UILabel {
    private static let sidePadding: CGFloat = 3

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + Self.sidePadding * 2, height: size.height)
    }
}

final class TopBarControl: UIControl {
    static let height: CGFloat = 40

    private static let touchSide: CGFloat = 44

    private let badge = BadgeLabel()

    init(background: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = background
        heightAnchor.constraint(equalToConstant: Self.height).isActive = true
        addOutline()
    }

    // A layer's own border draws above its sublayers, so it would cross the badge.
    private func addOutline() {
        let outline = UIView()
        outline.translatesAutoresizingMaskIntoConstraints = false
        outline.isUserInteractionEnabled = false
        outline.layer.borderWidth = 2
        outline.layer.borderColor = Palette.controlBorder.cgColor
        addSubview(outline)
        NSLayoutConstraint.activate([
            outline.topAnchor.constraint(equalTo: topAnchor),
            outline.bottomAnchor.constraint(equalTo: bottomAnchor),
            outline.leadingAnchor.constraint(equalTo: leadingAnchor),
            outline.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
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
        badge.text = text.isEmpty ? nil : text
        badge.isHidden = text.isEmpty
    }

    func embed(_ content: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        content.isUserInteractionEnabled = false
        insertSubview(content, at: 0)
    }
}
