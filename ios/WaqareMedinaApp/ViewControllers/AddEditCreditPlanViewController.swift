import UIKit

/// Supporting form for SRS 8.3 (Installment Sale Workflow) / 4.8: creates
/// a new CUSTOMER installment credit plan for one laptop sold from
/// Inventory. Shopkeepers no longer go through this screen -- they use
/// their own running account (ShopkeeperDetailViewController: one bill,
/// manually-entered laptops, "Add another laptop") instead of a
/// per-laptop CreditPlan.
final class AddEditCreditPlanViewController: UIViewController {
    private let personNameField = FormTextField(label: "Customer Name *")
    private let personPhoneField = FormTextField(label: "Phone Number *", keyboardType: .phonePad)
    private let laptopButton = UIButton(type: .system)
    private var selectedLaptop: Laptop?
    private let totalAmountField = FormTextField(label: "Total Laptop Price *", keyboardType: .decimalPad)
    private let downPaymentField = FormTextField(label: "Initial Down Payment", keyboardType: .decimalPad)
    private let installmentAmountField = FormTextField(label: "Installment Amount *", keyboardType: .decimalPad)
    private let dueDatePicker = UIDatePicker()
    private let notesField = FormTextField(label: "Notes")
    private let saveButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "New Credit Plan"
        enableTapToDismissKeyboard()

        dueDatePicker.datePickerMode = .date
        dueDatePicker.preferredDatePickerStyle = .wheels
        dueDatePicker.minimumDate = Date()

        laptopButton.setTitle("Select Laptop *", for: .normal)
        laptopButton.addTarget(self, action: #selector(pickLaptop), for: .touchUpInside)

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        saveButton.setTitle("Save Credit Plan", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        // Save is pinned as a fixed footer (outside the scroll view) rather
        // than as the last item in the scrollable stack, so it's always
        // reachable without having to scroll through every field first.
        let footer = UIView()
        footer.backgroundColor = .systemBackground
        footer.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(saveButton)

        let stack = UIStackView(arrangedSubviews: [
            personNameField, personPhoneField, laptopButton, totalAmountField,
            downPaymentField, installmentAmountField, dueDatePicker, notesField, errorLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 14
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
    }

    @objc private func pickLaptop() {
        let vc = InventoryViewController()
        vc.onLaptopSelected = { [weak self] laptop in
            guard let self = self else { return }
            self.selectedLaptop = laptop
            self.laptopButton.setTitle("\(laptop.brand) \(laptop.modelName)", for: .normal)
            // Pre-fill the plan's total from the laptop's own sale price —
            // still fully editable, just a sensible starting point.
            self.totalAmountField.text = "\(laptop.finalPrice)"
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func save() {
        errorLabel.isHidden = true
        do {
            let name = try Validator.requireNonEmpty(personNameField.text, fieldName: "customer name")
            let phone = try Validator.requireNonEmpty(personPhoneField.text, fieldName: "phone number")
            guard let laptop = selectedLaptop else { throw ValidationError.emptyField("laptop") }
            let total = try Validator.requirePositiveDecimal(totalAmountField.text, fieldName: "total laptop price")
            let down = Decimal(string: downPaymentField.text ?? "") ?? 0
            let installment = try Validator.requirePositiveDecimal(installmentAmountField.text, fieldName: "installment amount")

            saveButton.isEnabled = false
            Task {
                do {
                    let customerId = try await CustomerService.shared.findOrCreate(name: name, phone: phone).id
                    let form = CreditPlanFormData(
                        shopkeeper: nil, customer: customerId, laptop: laptop.id,
                        total_amount: total, down_payment: down, installment_amount: installment,
                        due_date: AppDateFormat.apiDate.string(from: self.dueDatePicker.date),
                        notes: self.notesField.text
                    )
                    _ = try await PaymentService.shared.createCreditPlan(form)
                    await MainActor.run { self.showSuccessThenPop("Credit plan saved successfully.") }
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
