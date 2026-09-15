import UIKit

/// Creates a shopkeeper account for the FIRST time only. Before creating,
/// checks whether a shopkeeper with this phone number already exists --
/// if so, opens their existing account (with "Add another laptop") instead
/// of creating a duplicate, matching the owner's "a name should never be
/// added a second time" requirement.
final class AddShopkeeperViewController: UIViewController {
    private let nameField = FormTextField(label: "Shopkeeper Name *")
    private let phoneField = FormTextField(label: "Phone Number *", keyboardType: .phonePad)
    private let cnicField = FormTextField(label: "CNIC (optional)")
    private let addressField = FormTextField(label: "Address")
    private let notesField = FormTextField(label: "Notes")
    private let saveButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "New Shopkeeper"
        enableTapToDismissKeyboard()

        for field in [nameField, phoneField, cnicField, addressField, notesField] {
            Theme.styleLargeField(field.textField)
        }

        let hint = UILabel()
        hint.text = "Create this once per shopkeeper. If they already have an account, search for their name on the previous screen and use \"Add Another Laptop\" instead."
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        Theme.stylePrimaryButton(saveButton, title: "Save Shopkeeper")
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [hint, nameField, phoneField, cnicField, addressField, notesField, errorLabel, saveButton])
        stack.axis = .vertical
        stack.spacing = 16
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
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
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
            let name = try Validator.requireNonEmpty(nameField.text, fieldName: "shopkeeper name")
            let phone = try Validator.requireNonEmpty(phoneField.text, fieldName: "phone number")

            saveButton.isEnabled = false
            Task {
                do {
                    // Never add the same shopkeeper twice: check for an
                    // existing account with this phone number first.
                    let existing = try await ShopkeeperService.shared.list(search: phone)
                    if let match = existing.first(where: { $0.phone == phone }) {
                        await MainActor.run { self.offerExisting(match) }
                        return
                    }

                    let created = try await ShopkeeperService.shared.create(
                        name: name, phone: phone,
                        cnic: self.cnicField.text, address: self.addressField.text, notes: self.notesField.text
                    )
                    await MainActor.run {
                        let detail = ShopkeeperDetailViewController(shopkeeperId: created.id)
                        var stack = self.navigationController?.viewControllers ?? []
                        stack.removeLast() // drop this form so back goes to the list, not back to the form
                        stack.append(detail)
                        self.navigationController?.setViewControllers(stack, animated: true)
                    }
                } catch {
                    await MainActor.run { self.showError(error) }
                }
                await MainActor.run { self.saveButton.isEnabled = true }
            }
        } catch {
            showError(error)
        }
    }

    private func offerExisting(_ shopkeeper: Shopkeeper) {
        let alert = UIAlertController(
            title: "Shopkeeper Already Exists",
            message: "\(shopkeeper.name) already has an account (\(shopkeeper.referenceNumber)). Opening their account so you can add another laptop instead of creating a duplicate.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let detail = ShopkeeperDetailViewController(shopkeeperId: shopkeeper.id)
            var stack = self.navigationController?.viewControllers ?? []
            stack.removeLast()
            stack.append(detail)
            self.navigationController?.setViewControllers(stack, animated: true)
        })
        present(alert, animated: true)
        saveButton.isEnabled = true
    }

    private func showError(_ error: Error) {
        errorLabel.text = error.localizedDescription
        errorLabel.isHidden = false
        presentErrorAlert(error)
    }
}
