import UIKit

/// SRS 14 (UI/UX): 'Large, readable controls and forms suitable for
/// iPhone.' A single reusable labeled text field used by every Add/Edit
/// form screen for visual consistency.
final class FormTextField: UIView {
    let textField = UITextField()
    private let label = UILabel()

    init(label text: String, placeholder: String = "", keyboardType: UIKeyboardType = .default) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel

        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 17)

        let stack = UIStackView(arrangedSubviews: [label, textField])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    var text: String? {
        get { textField.text }
        set { textField.text = newValue }
    }

    /// Adds a tappable eye icon inside the field that toggles whether the
    /// entered text is masked. Call this instead of setting
    /// `textField.isSecureTextEntry` directly on password fields, so the
    /// user has a way to double-check what they typed (SRS 14: usable,
    /// readable forms) before submitting.
    func enableSecureEntryToggle() {
        textField.isSecureTextEntry = true
        let button = UIButton(type: .system)
        button.tintColor = .secondaryLabel
        button.setImage(UIImage(systemName: "eye"), for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 24)
        button.addTarget(self, action: #selector(toggleSecureEntry), for: .touchUpInside)
        textField.rightView = button
        textField.rightViewMode = .always
    }

    @objc private func toggleSecureEntry() {
        textField.isSecureTextEntry.toggle()
        // Re-set text: UITextField can otherwise drop/garble the current
        // string when isSecureTextEntry flips while it's first responder.
        let current = textField.text
        textField.text = nil
        textField.text = current
        guard let button = textField.rightView as? UIButton else { return }
        let symbol = textField.isSecureTextEntry ? "eye" : "eye.slash"
        button.setImage(UIImage(systemName: symbol), for: .normal)
    }
}
