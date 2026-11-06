import UIKit

final class SignInViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ground

        let wordmark = UIImageView(image: UIImage(named: "wordmark"))
        wordmark.contentMode = .scaleAspectFit
        wordmark.accessibilityLabel = "Gameble"
        wordmark.isAccessibilityElement = true

        let button = PrimaryButton(title: Gameble.text("Sign in", "Se connecter"))
        button.addAction(UIAction { _ in SignIn.shared.start() }, for: .touchUpInside)

        let topSpace = UIView()
        let bottomSpace = UIView()
        let tagline = Self.caption(
            Gameble.text("A free trading card game of Steam games", "Un jeu de cartes gratuit de jeux Steam"), size: 14
        )
        let methods = Self.caption(
            Gameble.text("Steam, Apple, Discord, Google or an email code", "Steam, Apple, Discord, Google ou un code par e-mail"), size: 12
        )
        let acceptance = Self.acceptance()

        let column = UIStackView(arrangedSubviews: [topSpace, wordmark, tagline, bottomSpace, button, methods, acceptance])
        column.axis = .vertical
        column.setCustomSpacing(20, after: wordmark)
        column.setCustomSpacing(14, after: button)
        column.setCustomSpacing(28, after: methods)
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: safeArea.topAnchor),
            column.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -20),
            column.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 24),
            column.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -24),
            topSpace.heightAnchor.constraint(equalTo: bottomSpace.heightAnchor),
            wordmark.heightAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private static func caption(_ text: String, size: CGFloat) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = Typeface.regular(size)
        label.textColor = Palette.muted
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    private static func acceptance() -> UITextView {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 2
        let plain: [NSAttributedString.Key: Any] = [.font: Typeface.regular(11), .foregroundColor: Palette.dim, .paragraphStyle: paragraph]

        let text = NSMutableAttributedString()
        let add = { (part: String, fragment: String?) in
            var attributes = plain
            if let fragment { attributes[.link] = URL(string: "\(Gameble.url("/legal").absoluteString)#\(fragment)") }
            text.append(NSAttributedString(string: part, attributes: attributes))
        }
        add(Gameble.text("By signing in you accept the ", "En vous connectant, vous acceptez les "), nil)
        add(Gameble.text("terms of use", "conditions d\u{2019}utilisation"), "legal-terms")
        add(Gameble.text(" and acknowledge the ", " et prenez connaissance de la "), nil)
        add(Gameble.text("privacy notice", "politique de confidentialité"), "legal-privacy")
        add(".", nil)

        let view = UITextView()
        view.attributedText = text
        view.linkTextAttributes = [.foregroundColor: Palette.muted, .underlineStyle: NSUnderlineStyle.single.rawValue]
        view.backgroundColor = .clear
        view.isEditable = false
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        return view
    }
}

private final class PrimaryButton: UIControl {
    private static let depth: CGFloat = 4

    private let face = UIView()
    private lazy var faceTop = face.topAnchor.constraint(equalTo: topAnchor)
    private lazy var faceBottom = face.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.depth)

    override var isHighlighted: Bool {
        didSet {
            face.backgroundColor = isHighlighted ? Palette.primaryPressed : Palette.primary
            faceTop.constant = isHighlighted ? Self.depth : 0
            faceBottom.constant = isHighlighted ? 0 : -Self.depth
        }
    }

    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = Palette.primaryShade
        accessibilityLabel = title
        accessibilityTraits = .button
        isAccessibilityElement = true

        let label = UILabel()
        label.attributedText = NSAttributedString(string: title.uppercased(), attributes: [
            .font: Typeface.bold(16),
            .foregroundColor: Palette.onPrimary,
            .kern: 16 * 0.08
        ])
        label.translatesAutoresizingMaskIntoConstraints = false

        face.backgroundColor = Palette.primary
        face.isUserInteractionEnabled = false
        face.translatesAutoresizingMaskIntoConstraints = false
        face.addSubview(label)
        addSubview(face)

        NSLayoutConstraint.activate([
            faceTop,
            faceBottom,
            face.leadingAnchor.constraint(equalTo: leadingAnchor),
            face.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerXAnchor.constraint(equalTo: face.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: face.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
