import UIKit

/// One payment, always explicitly targeted at ONE thing -- a specific
/// laptop or the extra money -- via the dropdown below, per owner
/// request: "add option of extra money clearances or laptops clearances,
/// make a dropdown ... after selecting laptop that shopkeeper is paying
/// of which laptop payment and it's remaining payment should also be
/// shown". The shopkeeper's one combined bill total still adds up across
/// every payment regardless of what each one targets, and Notes always
/// travels with the payment and stays visible everywhere it's shown.
final class AddShopkeeperPaymentViewController: UIViewController {
    private let shopkeeper: Shopkeeper
    /// Non-nil when correcting an already-recorded payment's amount/note
    /// instead of adding a new one. The target itself can't be changed
    /// here -- delete and re-add if it was recorded against the wrong thing.
    private let editingPayment: ShopkeeperPayment?

    var onSaved: (() -> Void)?

    /// Every laptop/extra-money entry that still has a balance -- fully
    /// cleared ones aren't offered since there's nothing left to pay.
    private lazy var availableTargets: [ShopkeeperPaymentTarget] =
        shopkeeper.laptops.filter { $0.remainingAmount > 0 }.map { .laptop($0) }
        + shopkeeper.extraMoney.filter { $0.remainingAmount > 0 }.map { .extraMoney($0) }

    private var selectedTarget: ShopkeeperPaymentTarget?

    private let targetField = FormTextField(label: "This payment clears *", placeholder: "Tap to choose Extra Money or a laptop")
    private let remainingLabel = UILabel()
    private let amountField = FormTextField(label: "Amount Received *", keyboardType: .decimalPad)
    private let methodControl = UISegmentedControl(items: PaymentMethod.allCases.map { $0.rawValue.capitalized })
    private let noteField = FormTextField(label: "Note")
    private let saveButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    init(shopkeeper: Shopkeeper, editingPayment: ShopkeeperPayment? = nil) {
        self.shopkeeper = shopkeeper
        self.editingPayment = editingPayment
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    /// The balance this payment can validly be set to, for whichever
    /// target is selected. When editing, the payment's own old amount is
    /// added back first -- it's already subtracted out of the target's
    /// remainingAmount, and re-validating against that as-is would make
    /// almost every edit look like it overshoots (mirrors the backend's
    /// own edit validation).
    private var availableForThisPayment: Decimal {
        (selectedTarget?.remainingAmount ?? 0) + (editingPayment?.amount ?? 0)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = editingPayment == nil ? "Add Payment" : "Edit Payment"
        enableTapToDismissKeyboard()

        remainingLabel.font = .boldSystemFont(ofSize: 18)
        remainingLabel.numberOfLines = 0

        Theme.styleLargeField(targetField.textField)
        Theme.styleLargeField(amountField.textField)
        Theme.styleLargeField(noteField.textField)
        targetField.textField.inputView = UIView() // block the system keyboard; selection happens via the action sheet below
        targetField.textField.addTarget(self, action: #selector(chooseTarget), for: .editingDidBegin)

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        if let payment = editingPayment {
            // Editing: the target is fixed, shown for context only.
            if let laptopId = payment.laptopItem, let item = shopkeeper.laptops.first(where: { $0.id == laptopId }) {
                selectedTarget = .laptop(item)
            } else if let extraId = payment.extraMoney, let entry = shopkeeper.extraMoney.first(where: { $0.id == extraId }) {
                selectedTarget = .extraMoney(entry)
            }
            targetField.text = selectedTarget?.label
            targetField.textField.isEnabled = false
            amountField.text = "\(payment.amount)"
            if let index = PaymentMethod.allCases.firstIndex(of: payment.method) {
                methodControl.selectedSegmentIndex = index
            }
            noteField.text = payment.note
            updateRemainingLabel()
        } else {
            remainingLabel.text = "Choose what this payment clears above."
            // Same fix as AddPaymentViewController: UISegmentedControl has
            // no segment selected by default (selectedSegmentIndex == -1),
            // so saving a new payment without ever tapping Cash/Bank/Other
            // indexed PaymentMethod.allCases with -1 and crashed the app.
            methodControl.selectedSegmentIndex = 0
        }

        Theme.stylePrimaryButton(saveButton, title: editingPayment == nil ? "Save Payment" : "Save Changes")
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [targetField, remainingLabel, amountField, methodControl, noteField, errorLabel, saveButton])
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

    @objc private func chooseTarget() {
        targetField.textField.resignFirstResponder()
        guard editingPayment == nil else { return } // fixed once recorded

        let sheet = UIAlertController(title: "This payment clears...", message: nil, preferredStyle: .actionSheet)
        if availableTargets.isEmpty {
            sheet.message = "Everything on this account is already fully paid."
        }
        for target in availableTargets {
            let remaining = CurrencyFormatter.format(target.remainingAmount)
            sheet.addAction(UIAlertAction(title: "\(target.label)  ·  Remaining: \(remaining)", style: .default) { [weak self] _ in
                self?.selectedTarget = target
                self?.targetField.text = target.label
                self?.updateRemainingLabel()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = targetField
            popover.sourceRect = targetField.bounds
        }
        present(sheet, animated: true)
    }

    private func updateRemainingLabel() {
        guard let selectedTarget else { return }
        let emoji = { if case .extraMoney = selectedTarget { return "💵 " } else { return "💻 " } }()
        remainingLabel.text = "\(emoji)\(shopkeeper.name) -- Remaining on this: \(CurrencyFormatter.format(availableForThisPayment))"
    }

    @objc private func save() {
        errorLabel.isHidden = true
        do {
            guard let selectedTarget else {
                throw ValidationDisplayError.message("Choose what this payment clears first.")
            }
            let amount = try Validator.requirePositiveDecimal(amountField.text, fieldName: "amount")
            try Validator.validatePayment(amount: amount, remaining: availableForThisPayment)
            // Defensive: guard against -1 (no selection) instead of
            // crashing, even though we default this to 0 above.
            guard methodControl.selectedSegmentIndex >= 0 else {
                throw ValidationDisplayError.message("Choose a payment method (Cash, Bank, or Other).")
            }
            let method = PaymentMethod.allCases[methodControl.selectedSegmentIndex]

            let alert = UIAlertController(
                title: editingPayment == nil ? "Confirm Payment" : "Confirm Changes",
                message: editingPayment == nil
                    ? "Record \(CurrencyFormatter.format(amount)) clearing \(selectedTarget.label)?"
                    : "Update this payment to \(CurrencyFormatter.format(amount))?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
                self?.submit(amount: amount, method: method, target: selectedTarget)
            })
            present(alert, animated: true)
        } catch {
            errorLabel.text = error.localizedDescription
            errorLabel.isHidden = false
        }
    }

    private func submit(amount: Decimal, method: PaymentMethod, target: ShopkeeperPaymentTarget) {
        saveButton.isEnabled = false
        Task {
            do {
                if let payment = editingPayment {
                    let request = UpdateShopkeeperPaymentRequest(amount: amount, method: method, note: noteField.text)
                    _ = try await ShopkeeperService.shared.updatePayment(id: payment.id, request)
                    await MainActor.run {
                        self.onSaved?()
                        self.showSuccessThenPop("Payment updated.")
                    }
                } else {
                    var laptopId: Int?
                    var extraMoneyId: Int?
                    switch target {
                    case .laptop(let item): laptopId = item.id
                    case .extraMoney(let entry): extraMoneyId = entry.id
                    }
                    let request = NewShopkeeperPaymentRequest(
                        shopkeeper: shopkeeper.id, laptopItem: laptopId, extraMoney: extraMoneyId,
                        amount: amount, method: method, note: noteField.text
                    )
                    _ = try await ShopkeeperService.shared.addPayment(request)
                    await MainActor.run {
                        self.onSaved?()
                        self.showSuccessThenPop("Payment recorded and marked on the bill.")
                    }
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

/// Small local error so `chooseTarget` validation reads naturally in the
/// same do/catch as `Validator`'s own throwing helpers.
private enum ValidationDisplayError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let text) = self { return text }
        return nil
    }
}
