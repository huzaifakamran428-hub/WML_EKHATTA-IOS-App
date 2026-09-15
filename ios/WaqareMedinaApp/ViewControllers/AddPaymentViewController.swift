import UIKit

/// Screen 13 — SRS 4.9: Add payment form launched by + action.
final class AddPaymentViewController: UIViewController {
    private let plan: CreditPlan
    var onSaved: (() -> Void)?

    private let remainingLabel = UILabel()
    private let amountField = FormTextField(label: "Amount Received *", keyboardType: .decimalPad)
    private let methodControl = UISegmentedControl(items: PaymentMethod.allCases.map { $0.rawValue.capitalized })
    private let noteField = FormTextField(label: "Note")
    private let saveButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    init(plan: CreditPlan) {
        self.plan = plan
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Add Payment"
        enableTapToDismissKeyboard()

        remainingLabel.text = "Remaining: \(CurrencyFormatter.format(plan.remainingAmount))"
        remainingLabel.font = .boldSystemFont(ofSize: 17)

        // UISegmentedControl starts with NO segment selected
        // (selectedSegmentIndex == -1) until the user taps one. Saving
        // without ever tapping Cash/Bank/Other indexed PaymentMethod.allCases
        // with -1 and crashed. Default to the first method so there's
        // always a valid selection.
        methodControl.selectedSegmentIndex = 0

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        saveButton.setTitle("Save Payment", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [remainingLabel, amountField, methodControl, noteField, errorLabel, saveButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Same fix as AddShopkeeperPaymentViewController: wrap in a scroll
        // view so the keyboard can't strand the amount field or Save button
        // with no way to reach them.
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
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
        ])
        registerKeyboardAvoidance(for: scroll)
    }

    @objc private func save() {
        errorLabel.isHidden = true
        do {
            let amount = try Validator.requirePositiveDecimal(amountField.text, fieldName: "amount")
            // SRS 4.9 / 17: 'Payment amount cannot be greater than the remaining amount.'
            try Validator.validatePayment(amount: amount, remaining: plan.remainingAmount)
            // Defensive: even though we default this to 0 above, guard
            // against -1 (no selection) instead of crashing if that ever
            // changes.
            guard methodControl.selectedSegmentIndex >= 0 else {
                throw ValidationError.emptyField("payment method")
            }
            let method = PaymentMethod.allCases[methodControl.selectedSegmentIndex]

            // SRS 14: confirmation dialog for recording a payment.
            let alert = UIAlertController(title: "Confirm Payment", message: "Record \(CurrencyFormatter.format(amount)) for this credit plan?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
                self?.submit(amount: amount, method: method)
            })
            present(alert, animated: true)
        } catch {
            errorLabel.text = error.localizedDescription
            errorLabel.isHidden = false
        }
    }

    private func submit(amount: Decimal, method: PaymentMethod) {
        saveButton.isEnabled = false
        Task {
            do {
                let request = NewPaymentRequest(creditPlan: plan.id, amount: amount, method: method, note: noteField.text)
                _ = try await PaymentService.shared.addPayment(request)
                await MainActor.run {
                    self.onSaved?()
                    self.showSuccessThenPop("Payment recorded successfully.")
                }
            } catch {
                await MainActor.run { self.showError(error) }
            }
            await MainActor.run { self.saveButton.isEnabled = true }
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
