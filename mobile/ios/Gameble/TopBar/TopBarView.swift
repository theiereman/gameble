import UIKit

final class TopBarView: UIView {
    enum Left: Equatable {
        case home
        case back(String)
    }

    static let height: CGFloat = 56

    private static let rule: CGFloat = 2
    private static let sideMargin: CGFloat = 10
    private static let controlGap: CGFloat = 6

    var onBack: (() -> Void)?
    var onCapsules: (() -> Void)?
    var onBell: (() -> Void)?
    var onMenu: (() -> Void)?

    private let content = UIView()
    private let home = UIImageView(image: UIImage(named: "bar-g"))
    private let back = TopBarControl(background: Palette.raised)
    private let backLabel = UILabel()
    private let capsules = TopBarControl(background: Palette.sunken)
    private let standard = TopBarView.countLabel()
    private let special = TopBarView.countLabel()
    private let specialIcon = UIImageView(image: UIImage(named: "bar-capsule-special"))
    private let bell = TopBarControl(background: Palette.sunken)
    private let menu = TopBarControl(background: Palette.sunken)
    private let avatar = UIImageView()
    private var shownAvatar = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.steamBar
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        let rule = UIView()
        rule.translatesAutoresizingMaskIntoConstraints = false
        rule.backgroundColor = Palette.line
        addSubview(rule)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            rule.leadingAnchor.constraint(equalTo: leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: trailingAnchor),
            rule.bottomAnchor.constraint(equalTo: bottomAnchor),
            rule.heightAnchor.constraint(equalToConstant: Self.rule),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: rule.topAnchor)
        ])
        layOutLeftSide()
        layOutRightSide()
        back.addAction(UIAction { [weak self] _ in self?.onBack?() }, for: .touchUpInside)
        capsules.addAction(UIAction { [weak self] _ in self?.onCapsules?() }, for: .touchUpInside)
        bell.addAction(UIAction { [weak self] _ in self?.onBell?() }, for: .touchUpInside)
        menu.addAction(UIAction { [weak self] _ in self?.onMenu?() }, for: .touchUpInside)
        show(.home)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ left: Left) {
        switch left {
        case .home:
            home.isHidden = false
            back.isHidden = true
        case .back(let label):
            home.isHidden = true
            back.isHidden = false
            backLabel.attributedText = NSAttributedString(string: label.uppercased(), attributes: [
                .font: Typeface.bold(12),
                .foregroundColor: UIColor.white,
                .kern: 0.72
            ])
            back.accessibilityLabel = "\(Gameble.text("Back to", "Retour à")) \(label)"
        }
    }

    func render(_ state: TopBarState) {
        standard.text = state.standard
        special.text = state.special
        let noneSpecial = state.special.isEmpty || state.special == "0"
        special.alpha = noneSpecial ? 0.55 : 1
        specialIcon.alpha = noneSpecial ? 0.55 : 1
        bell.showBadge(state.bell)
        menu.showBadge(state.menuBadge)
        renderAvatar(state.avatar)
        describeControls(state)
    }

    private func describeControls(_ state: TopBarState) {
        capsules.accessibilityLabel = state.standard.isEmpty
            ? Gameble.text("Capsules", "Capsules")
            : Gameble.text("Capsules, standard: \(state.standard), special: \(state.special)", "Capsules, standard : \(state.standard), spéciales : \(state.special)")
        bell.accessibilityLabel = state.bell.isEmpty
            ? Gameble.text("What's new", "Nouveautés")
            : Gameble.text("What's new, unread: \(state.bell)", "Nouveautés, non lues : \(state.bell)")
        menu.accessibilityLabel = state.menuBadge.isEmpty
            ? Gameble.text("Menu", "Menu")
            : Gameble.text("Menu, rewards waiting: \(state.menuBadge)", "Menu, récompenses en attente : \(state.menuBadge)")
    }

    func setDimmed(_ dimmed: Bool) {
        content.alpha = dimmed ? 0.4 : 1
        [back, capsules, bell, menu].forEach { $0.isEnabled = !dimmed }
    }

    private func renderAvatar(_ source: String) {
        guard source != shownAvatar else { return }
        shownAvatar = source
        let encoded = source.split(separator: ",", maxSplits: 1).last.map(String.init) ?? ""
        avatar.image = Data(base64Encoded: encoded).flatMap { UIImage(data: $0) }
    }

    private func layOutLeftSide() {
        home.translatesAutoresizingMaskIntoConstraints = false
        home.contentMode = .scaleAspectFit
        home.isAccessibilityElement = true
        home.accessibilityLabel = "Gameble"
        content.addSubview(home)
        content.addSubview(back)

        let arrow = UIImageView(image: UIImage(named: "bar-arrow"))
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.contentMode = .scaleAspectFit
        back.embed(arrow)
        backLabel.translatesAutoresizingMaskIntoConstraints = false
        backLabel.lineBreakMode = .byTruncatingTail
        backLabel.numberOfLines = 1
        backLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        back.embed(backLabel)
        back.isAccessibilityElement = true
        back.accessibilityTraits = .button

        NSLayoutConstraint.activate([
            home.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.sideMargin),
            home.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            home.heightAnchor.constraint(equalToConstant: 30),
            home.widthAnchor.constraint(equalTo: home.heightAnchor, multiplier: 37.0 / 50.0),
            back.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.sideMargin),
            back.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            arrow.leadingAnchor.constraint(equalTo: back.leadingAnchor, constant: 10),
            arrow.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 7),
            arrow.heightAnchor.constraint(equalToConstant: 12),
            backLabel.leadingAnchor.constraint(equalTo: arrow.trailingAnchor, constant: 7),
            backLabel.trailingAnchor.constraint(equalTo: back.trailingAnchor, constant: -10),
            backLabel.centerYAnchor.constraint(equalTo: back.centerYAnchor)
        ])
    }

    private func layOutRightSide() {
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = Palette.line
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 2),
            separator.heightAnchor.constraint(equalToConstant: 18)
        ])
        let row = UIStackView(arrangedSubviews: [
            Self.icon(UIImageView(image: UIImage(named: "bar-capsule-standard")), width: 18.0 * 7 / 11),
            standard,
            separator,
            Self.icon(specialIcon, width: 18),
            special
        ])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 5
        capsules.embed(row)
        capsules.isAccessibilityElement = true
        capsules.accessibilityTraits = .button

        let bellIcon = Self.icon(UIImageView(image: UIImage(named: "bar-bell")), width: 14)
        bell.embed(bellIcon)
        bell.addBadge()
        bell.isAccessibilityElement = true
        bell.accessibilityTraits = .button

        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.contentMode = .scaleAspectFill
        avatar.layer.magnificationFilter = .nearest
        avatar.layer.minificationFilter = .nearest
        menu.embed(avatar)
        menu.addBadge()
        menu.isAccessibilityElement = true
        menu.accessibilityTraits = .button

        let right = UIStackView(arrangedSubviews: [capsules, bell, menu])
        right.translatesAutoresizingMaskIntoConstraints = false
        right.axis = .horizontal
        right.alignment = .center
        right.spacing = Self.controlGap
        right.setContentHuggingPriority(.required, for: .horizontal)
        right.setContentCompressionResistancePriority(.required, for: .horizontal)
        content.addSubview(right)

        NSLayoutConstraint.activate([
            right.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.sideMargin),
            right.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            back.trailingAnchor.constraint(lessThanOrEqualTo: right.leadingAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: capsules.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: capsules.trailingAnchor, constant: -8),
            row.centerYAnchor.constraint(equalTo: capsules.centerYAnchor),
            bell.widthAnchor.constraint(equalToConstant: TopBarControl.height),
            bellIcon.centerXAnchor.constraint(equalTo: bell.centerXAnchor),
            bellIcon.centerYAnchor.constraint(equalTo: bell.centerYAnchor),
            bellIcon.heightAnchor.constraint(equalToConstant: 16),
            menu.widthAnchor.constraint(equalToConstant: TopBarControl.height),
            avatar.centerXAnchor.constraint(equalTo: menu.centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: menu.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 36),
            avatar.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private static func countLabel() -> UILabel {
        let label = UILabel()
        label.font = Typeface.bold(13)
        label.textColor = .white
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private static func icon(_ image: UIImageView, width: CGFloat) -> UIImageView {
        image.translatesAutoresizingMaskIntoConstraints = false
        image.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: width),
            image.heightAnchor.constraint(lessThanOrEqualToConstant: 18)
        ])
        return image
    }
}
