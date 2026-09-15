import UIKit

/// Screen 20 — SRS 4.13 / 15: store name/address/phone/logo management,
/// notification preference toggles.
final class StoreProfileViewController: UIViewController {
    private let nameField = FormTextField(label: "Store Name")
    private let addressField = FormTextField(label: "Address")
    private let phoneField = FormTextField(label: "Phone Number", keyboardType: .phonePad)
    private let ceoNameField = FormTextField(label: "CEO Name")
    private let ceoContactField = FormTextField(label: "CEO Contact No.", keyboardType: .phonePad)
    private let thankYouField = FormTextField(label: "Thank-you Message")
    private let lowStockSwitch = UISwitch()
    private let dueTodaySwitch = UISwitch()
    private let twoDaySwitch = UISwitch()
    private let saveButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Store Profile"
        enableTapToDismissKeyboard()

        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        func toggleRow(_ label: String, _ toggle: UISwitch) -> UIStackView {
            let l = UILabel(); l.text = label
            let row = UIStackView(arrangedSubviews: [l, toggle])
            row.distribution = .equalSpacing
            return row
        }

        // Save is pinned as a fixed footer (outside the scroll view) rather
        // than as the last item in the scrollable stack, so it's always
        // reachable without having to scroll through every field first.
        let footer = UIView()
        footer.backgroundColor = .systemBackground
        footer.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(saveButton)

        let stack = UIStackView(arrangedSubviews: [
            nameField, addressField, phoneField, ceoNameField, ceoContactField, thankYouField,
            toggleRow("Low Stock Alerts", lowStockSwitch),
            toggleRow("Due-Today Reminder", dueTodaySwitch),
            toggleRow("Two-Day Reminder", twoDaySwitch),
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        view.addSubview(scroll)
        view.addSubview(footer)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),

            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            saveButton.topAnchor.constraint(equalTo: footer.topAnchor, constant: 12),
            saveButton.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -12),
            saveButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
        ])
        registerKeyboardAvoidance(for: scroll)
        load()
    }

    private func load() {
        Task {
            do {
                let s = try await StoreSettingsService.shared.get()
                await MainActor.run {
                    self.nameField.text = s.storeName
                    self.addressField.text = s.address
                    self.phoneField.text = s.phoneNumber
                    self.ceoNameField.text = s.ceoName
                    self.ceoContactField.text = s.ceoContactNumber
                    self.thankYouField.text = s.thankYouMessage
                    self.lowStockSwitch.isOn = s.lowStockAlertsEnabled
                    self.dueTodaySwitch.isOn = s.dueTodayReminderEnabled
                    self.twoDaySwitch.isOn = s.twoDayReminderEnabled
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    @objc private func save() {
        let settings = StoreSettings(
            storeName: nameField.text ?? "", address: addressField.text ?? "", phoneNumber: phoneField.text ?? "",
            logoURL: nil, ceoName: ceoNameField.text ?? "", ceoContactNumber: ceoContactField.text ?? "",
            thankYouMessage: thankYouField.text ?? "", lowStockAlertsEnabled: lowStockSwitch.isOn,
            dueTodayReminderEnabled: dueTodaySwitch.isOn, twoDayReminderEnabled: twoDaySwitch.isOn
        )
        saveButton.isEnabled = false
        Task {
            do {
                _ = try await StoreSettingsService.shared.update(settings)
                await MainActor.run {
                    let alert = UIAlertController(title: "Success", message: "Store profile saved successfully.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                        self?.navigationController?.popViewController(animated: true)
                    })
                    self.present(alert, animated: true)
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
            await MainActor.run { self.saveButton.isEnabled = true }
        }
    }
}
