import UIKit

/// Screen 18 — SRS 4.1: create/edit/deactivate user (Admin only). Extended
/// with a "Shopkeeper" role: an admin-created login scoped to exactly one
/// shopkeeper, so they can sign in and see their own laptops, payments,
/// and remaining balance (read-only, nothing else in the app).
final class AddEditUserViewController: UIViewController {
    private let usernameField = FormTextField(label: "Username *")
    private let emailField = FormTextField(label: "Email *", keyboardType: .emailAddress)
    private let phoneField = FormTextField(label: "Phone Number")
    private let passwordField = FormTextField(label: "Temporary Password *")
    private let roleControl = UISegmentedControl(items: ["Read-Only User", "Admin", "Shopkeeper"])
    private let pickShopkeeperButton = UIButton(type: .system)
    private let selectedShopkeeperLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    private var selectedShopkeeper: Shopkeeper?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Add User"
        enableTapToDismissKeyboard()
        passwordField.enableSecureEntryToggle()

        for field in [usernameField, emailField, phoneField, passwordField] {
            Theme.styleLargeField(field.textField)
        }

        roleControl.selectedSegmentIndex = 0
        roleControl.addTarget(self, action: #selector(roleChanged), for: .valueChanged)

        Theme.styleSecondaryButton(pickShopkeeperButton, title: "Select Shopkeeper")
        pickShopkeeperButton.addTarget(self, action: #selector(pickShopkeeper), for: .touchUpInside)
        pickShopkeeperButton.isHidden = true

        selectedShopkeeperLabel.font = .systemFont(ofSize: 14, weight: .medium)
        selectedShopkeeperLabel.textColor = .secondaryLabel
        selectedShopkeeperLabel.text = "No shopkeeper selected yet."
        selectedShopkeeperLabel.isHidden = true

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        Theme.stylePrimaryButton(saveButton, title: "Create User")
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            usernameField, emailField, phoneField, roleControl,
            pickShopkeeperButton, selectedShopkeeperLabel,
            passwordField, errorLabel, saveButton,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    @objc private func roleChanged() {
        let isShopkeeperRole = roleControl.selectedSegmentIndex == 2
        pickShopkeeperButton.isHidden = !isShopkeeperRole
        selectedShopkeeperLabel.isHidden = !isShopkeeperRole
    }

    @objc private func pickShopkeeper() {
        let picker = PickShopkeeperViewController()
        picker.onPicked = { [weak self] shopkeeper in
            self?.selectedShopkeeper = shopkeeper
            self?.selectedShopkeeperLabel.text = "Selected: \(shopkeeper.name) (\(shopkeeper.referenceNumber))"
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    @objc private func save() {
        errorLabel.isHidden = true
        do {
            let username = try Validator.requireNonEmpty(usernameField.text, fieldName: "username")
            let email = try Validator.requireNonEmpty(emailField.text, fieldName: "email")
            let password = try Validator.requireNonEmpty(passwordField.text, fieldName: "password")
            let role: UserRole
            switch roleControl.selectedSegmentIndex {
            case 1: role = .admin
            case 2: role = .shopkeeper
            default: role = .readOnly
            }
            if role == .shopkeeper && selectedShopkeeper == nil {
                throw ValidationError.emptyField("shopkeeper this login belongs to")
            }

            saveButton.isEnabled = false
            Task {
                do {
                    _ = try await UserService.shared.create(
                        username: username, email: email, password: password, role: role,
                        phone: phoneField.text, shopkeeperId: selectedShopkeeper?.id
                    )
                    await MainActor.run { self.showSuccessThenPop("User created successfully.") }
                } catch {
                    await MainActor.run { self.showError(error) }
                }
                await MainActor.run { self.saveButton.isEnabled = true }
            }
        } catch {
            showError(error)
        }
    }

    private func showSuccessThenPop(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showError(_ error: Error) {
        errorLabel.text = error.localizedDescription
        errorLabel.isHidden = false
        presentErrorAlert(error)
    }
}
