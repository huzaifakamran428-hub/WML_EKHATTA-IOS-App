import UIKit

/// SRS 11: admin can correct a mis-entered bill after the fact (quantity,
/// price, discount, amount received, payment type, notes) rather than it
/// being permanently locked in. The laptop the sale was made against
/// can't be changed here — only re-record it as a new sale for that.
final class EditSaleViewController: UIViewController {
    private let sale: Sale
    private let laptop: Laptop?
    var onSaved: ((Sale) -> Void)?

    private let laptopLabel = UILabel()
    private let quantityField = FormTextField(label: "Quantity *", keyboardType: .numberPad)
    private let salePriceField = FormTextField(label: "Sale Price (per unit) *", keyboardType: .decimalPad)
    private let discountField = FormTextField(label: "Discount (amount)", keyboardType: .decimalPad)
    private let amountReceivedField = FormTextField(label: "Amount Received", keyboardType: .decimalPad)
    private let notesField = FormTextField(label: "Notes")
    private let paymentTypeControl = UISegmentedControl(items: PaymentType.allCases.map { $0.rawValue.capitalized })
    private let finalPriceLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    init(sale: Sale, laptop: Laptop?) {
        self.sale = sale
        self.laptop = laptop
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Edit Bill"
        enableTapToDismissKeyboard()

        let item = sale.items.first
        laptopLabel.font = .systemFont(ofSize: 14, weight: .medium)
        laptopLabel.textColor = .secondaryLabel
        laptopLabel.numberOfLines = 0
        laptopLabel.text = laptop.map { "\($0.brand) \($0.modelName) (Receipt #\(sale.receiptNo))" } ?? "Receipt #\(sale.receiptNo)"

        quantityField.text = "\(item?.quantity ?? 1)"
        salePriceField.text = "\(sale.salePrice)"
        discountField.text = "\(sale.discountAmount)"
        amountReceivedField.text = "\(sale.amountReceived)"
        notesField.text = sale.notes
        if let index = PaymentType.allCases.firstIndex(of: sale.paymentType) {
            paymentTypeControl.selectedSegmentIndex = index
        } else {
            // Same crash as the other forms: UISegmentedControl with no
            // segment selected (-1) crashes when later indexed into
            // PaymentType.allCases. Shouldn't normally happen since
            // sale.paymentType always comes from this same enum, but
            // falling back to a valid default instead of -1 costs nothing.
            paymentTypeControl.selectedSegmentIndex = 0
        }

        finalPriceLabel.font = .boldSystemFont(ofSize: 20)
        [quantityField, salePriceField, discountField].forEach {
            $0.textField.addTarget(self, action: #selector(recalculate), for: .editingChanged)
        }

        Theme.stylePrimaryButton(saveButton, title: "Save Changes")
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let footer = UIView()
        footer.backgroundColor = .systemBackground
        footer.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(saveButton)

        let stack = UIStackView(arrangedSubviews: [
            laptopLabel, quantityField, salePriceField, discountField,
            amountReceivedField, paymentTypeControl, notesField, finalPriceLabel, errorLabel,
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
        recalculate()
    }

    @objc private func recalculate() {
        guard let salePrice = Decimal(string: salePriceField.text ?? ""),
              let quantity = Int(quantityField.text ?? ""), quantity > 0 else {
            finalPriceLabel.text = "Final Price: —"
            return
        }
        let discount = Decimal(string: discountField.text ?? "") ?? 0
        let final = Laptop.previewFinalPrice(salePrice: salePrice * Decimal(quantity), discountAmount: discount, discountPercent: 0)
        finalPriceLabel.text = "Final Price: \(CurrencyFormatter.format(final))"
    }

    @objc private func saveTapped() {
        errorLabel.isHidden = true
        do {
            guard let quantity = Int(quantityField.text ?? ""), quantity > 0 else {
                throw ValidationError.emptyField("quantity")
            }
            let salePrice = try Validator.requirePositiveDecimal(salePriceField.text, fieldName: "sale price")
            let discount = Decimal(string: discountField.text ?? "") ?? 0
            let received = Decimal(string: amountReceivedField.text ?? "") ?? 0
            guard paymentTypeControl.selectedSegmentIndex >= 0 else {
                throw ValidationError.emptyField("payment type")
            }
            let paymentType = PaymentType.allCases[paymentTypeControl.selectedSegmentIndex]
            let notes = notesField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

            let alert = UIAlertController(
                title: "Confirm Changes",
                message: "Save changes to receipt #\(sale.receiptNo)?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
                self?.submit(quantity: quantity, salePrice: salePrice, discount: discount, received: received, paymentType: paymentType, notes: notes)
            })
            present(alert, animated: true)
        } catch {
            errorLabel.text = error.localizedDescription
            errorLabel.isHidden = false
            presentErrorAlert(error)
        }
    }

    private func submit(quantity: Int, salePrice: Decimal, discount: Decimal, received: Decimal, paymentType: PaymentType, notes: String?) {
        saveButton.isEnabled = false
        Task {
            do {
                let request = EditSaleRequest(
                    quantity: quantity, salePrice: salePrice, discountAmount: discount, discountPercent: 0,
                    paymentType: paymentType, amountReceived: received, notes: notes?.isEmpty == true ? nil : notes
                )
                let updated = try await SalesService.shared.update(id: sale.id, request)
                await MainActor.run {
                    self.onSaved?(updated)
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
            await MainActor.run { self.saveButton.isEnabled = true }
        }
    }
}
