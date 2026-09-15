import UIKit

/// "Add Extra Money 💵" -- SRS 9 extension per owner request: some
/// shopkeepers also take cash on top of their laptops. Recorded as its
/// own separate entry/receipt line here, but rolled into the shopkeeper's
/// one combined bill total once saved.
final class AddShopkeeperExtraMoneyViewController: UIViewController {
    private let shopkeeper: Shopkeeper
    private let existingEntry: ShopkeeperExtraMoney? // non-nil when correcting an already-added entry
    var onSaved: (() -> Void)?

    private let amountField = FormTextField(label: "Extra Money Amount (Rs.) *", placeholder: "e.g. 10000", keyboardType: .decimalPad)
    private let noteField = FormTextField(label: "Note", placeholder: "e.g. cash advance for shop rent")
    private let saveButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    init(shopkeeper: Shopkeeper, existingEntry: ShopkeeperExtraMoney? = nil) {
        self.shopkeeper = shopkeeper
        self.existingEntry = existingEntry
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingEntry == nil ? "💵 Add Extra Money" : "💵 Edit Extra Money"
        view.backgroundColor = .systemBackground
        enableTapToDismissKeyboard()

        Theme.styleLargeField(amountField.textField)
        Theme.styleLargeField(noteField.textField)

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let intro = UILabel()
        intro.numberOfLines = 0
        intro.font = .systemFont(ofSize: 15)
        intro.textColor = .secondaryLabel
        intro.text = "This is kept as its own record on \(shopkeeper.name)'s bill, but adds into their one combined total."

        if let entry = existingEntry {
            amountField.text = "\(entry.amount)"
            noteField.text = entry.note
        }

        Theme.stylePrimaryButton(saveButton, title: existingEntry == nil ? "Add Extra Money" : "Save Changes")
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [intro, amountField, noteField, errorLabel, saveButton])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40),
        ])
        registerKeyboardAvoidance(for: scroll)
    }

    @objc private func save() {
        errorLabel.isHidden = true
        do {
            let amount = try Validator.requirePositiveDecimal(amountField.text, fieldName: "amount")
            saveButton.isEnabled = false
            Task {
                do {
                    if let entry = existingEntry {
                        let request = UpdateShopkeeperExtraMoneyRequest(amount: amount, note: noteField.text)
                        _ = try await ShopkeeperService.shared.updateExtraMoney(id: entry.id, request)
                    } else {
                        let request = NewShopkeeperExtraMoneyRequest(shopkeeper: shopkeeper.id, amount: amount, note: noteField.text)
                        _ = try await ShopkeeperService.shared.addExtraMoney(request)
                    }
                    await MainActor.run {
                        self.onSaved?()
                        self.navigationController?.popViewController(animated: true)
                    }
                } catch {
                    await MainActor.run {
                        self.errorLabel.text = error.localizedDescription
                        self.errorLabel.isHidden = false
                        self.saveButton.isEnabled = true
                    }
                }
            }
        } catch {
            errorLabel.text = error.localizedDescription
            errorLabel.isHidden = false
        }
    }
}
