import UIKit

/// Shared "bigger, bolder, more modern" styling used across the app --
/// applied first to the login screen and the shopkeeper flow per the
/// owner's request, and safe to reuse anywhere else going forward.
enum Theme {
    static let brand = UIColor(red: 0.10, green: 0.15, blue: 0.30, alpha: 1)
    static let accent = UIColor(red: 0.90, green: 0.58, blue: 0.09, alpha: 1)
    static let cardBackground = UIColor.secondarySystemBackground

    static func stylePrimaryButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 18)
        button.backgroundColor = brand
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        button.heightAnchor.constraint(equalToConstant: 54).isActive = true
    }

    static func styleSecondaryButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.setTitleColor(brand, for: .normal)
        button.backgroundColor = brand.withAlphaComponent(0.08)
        button.layer.cornerRadius = 14
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }

    /// Large, modern rounded input field (bigger than the default
    /// FormTextField sizing) for the screens the owner asked to be more
    /// spacious -- login, and add-shopkeeper/add-laptop forms.
    static func styleLargeField(_ field: UITextField) {
        field.borderStyle = .none
        field.backgroundColor = cardBackground
        field.layer.cornerRadius = 14
        field.font = .systemFont(ofSize: 18)
        field.heightAnchor.constraint(equalToConstant: 56).isActive = true
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        field.leftView = padding
        field.leftViewMode = .always
    }

    static func cardView() -> UIView {
        let view = UIView()
        view.backgroundColor = cardBackground
        view.layer.cornerRadius = 16
        return view
    }

    static func pillLabel(text: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = "  \(text)  "
        label.font = .boldSystemFont(ofSize: 13)
        label.textColor = .white
        label.backgroundColor = color
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }
}
