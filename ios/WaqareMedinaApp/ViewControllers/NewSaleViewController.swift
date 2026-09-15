import UIKit

/// Screen 6 — SRS 4.5, 8.2 (Normal Sale Workflow): Customer + laptop +
/// price + discount + payment; instant final-price preview; confirmation
/// dialog before submitting.
final class NewSaleViewController: UIViewController {
    private var selectedLaptop: Laptop?
    private var selectedCustomer: Customer?

    private let laptopButton = UIButton(type: .system)
    private let customerNameField = FormTextField(label: "Customer Name *")
    private let customerPhoneField = FormTextField(label: "Customer Phone *", keyboardType: .phonePad)
    private let salePriceField = FormTextField(label: "Sale Price *", keyboardType: .decimalPad)
    private let discountField = FormTextField(label: "Discount (amount)", keyboardType: .decimalPad)
    private let amountReceivedField = FormTextField(label: "Amount Received", keyboardType: .decimalPad)
    private let paymentTypeControl = UISegmentedControl(items: PaymentType.allCases.map { $0.rawValue.capitalized })
    private let finalPriceLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    init(preselectedLaptop: Laptop? = nil) {
        self.selectedLaptop = preselectedLaptop
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "New Sale"
        enableTapToDismissKeyboard()

        laptopButton.setTitle(selectedLaptop.map { "\($0.brand) \($0.modelName)" } ?? "Select Laptop *", for: .normal)
        laptopButton.addTarget(self, action: #selector(pickLaptop), for: .touchUpInside)
        if let l = selectedLaptop { salePriceField.text = "\(l.salePrice)" }

        finalPriceLabel.font = .boldSystemFont(ofSize: 20)
        finalPriceLabel.text = "Final Price: —"

        // Same crash as the payment forms: UISegmentedControl starts with
        // NO segment selected (selectedSegmentIndex == -1), so confirming
        // a sale without ever tapping a payment type indexed
        // PaymentType.allCases with -1 and crashed.
        paymentTypeControl.selectedSegmentIndex = 0

        [salePriceField, discountField].forEach {
            $0.textField.addTarget(self, action: #selector(recalculate), for: .editingChanged)
        }

        confirmButton.setTitle("Confirm Sale", for: .normal)
        confirmButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        confirmButton.backgroundColor = .systemBlue
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 10
        confirmButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        // Confirm is pinned as a fixed footer (outside the scroll view)
        // rather than as the last item in the scrollable stack, so it's
        // always reachable without having to scroll through every field.
        let footer = UIView()
        footer.backgroundColor = .systemBackground
        footer.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(confirmButton)

        let stack = UIStackView(arrangedSubviews: [
            laptopButton, customerNameField, customerPhoneField, salePriceField, discountField,
            amountReceivedField, paymentTypeControl, finalPriceLabel, errorLabel,
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
            confirmButton.topAnchor.constraint(equalTo: footer.topAnchor, constant: 12),
            confirmButton.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -12),
            confirmButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
        ])
        registerKeyboardAvoidance(for: scroll)
        recalculate()
    }

    @objc private func pickLaptop() {
        let vc = InventoryViewController()
        vc.onLaptopSelected = { [weak self] laptop in
            guard let self = self else { return }
            self.selectedLaptop = laptop
            self.laptopButton.setTitle("\(laptop.brand) \(laptop.modelName)", for: .normal)
            self.salePriceField.text = "\(laptop.salePrice)"
            self.recalculate()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func recalculate() {
        guard let salePrice = Decimal(string: salePriceField.text ?? "") else {
            finalPriceLabel.text = "Final Price: —"
            return
        }
        let discount = Decimal(string: discountField.text ?? "") ?? 0
        let final = Laptop.previewFinalPrice(salePrice: salePrice, discountAmount: discount, discountPercent: 0)
        finalPriceLabel.text = "Final Price: \(CurrencyFormatter.format(final))"
    }

    @objc private func confirmTapped() {
        errorLabel.isHidden = true
        do {
            guard let laptop = selectedLaptop else { throw ValidationError.emptyField("laptop") }
            let name = try Validator.requireNonEmpty(customerNameField.text, fieldName: "customer name")
            let phone = try Validator.requireNonEmpty(customerPhoneField.text, fieldName: "customer phone")
            let salePrice = try Validator.requirePositiveDecimal(salePriceField.text, fieldName: "sale price")
            let discount = Decimal(string: discountField.text ?? "") ?? 0
            let received = Decimal(string: amountReceivedField.text ?? "") ?? 0
            // Defensive: guard against -1 (no selection) instead of
            // crashing, even though we default this to 0 above.
            guard paymentTypeControl.selectedSegmentIndex >= 0 else {
                throw ValidationError.emptyField("payment type")
            }
            let paymentType = PaymentType.allCases[paymentTypeControl.selectedSegmentIndex]

            // SRS 14: 'Confirmation dialogs for completing a sale.'
            let alert = UIAlertController(
                title: "Confirm Sale",
                message: "Sell \(laptop.brand) \(laptop.modelName) to \(name) for \(CurrencyFormatter.format(Laptop.previewFinalPrice(salePrice: salePrice, discountAmount: discount, discountPercent: 0)))?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
                self?.submitSale(laptop: laptop, name: name, phone: phone, salePrice: salePrice, discount: discount, received: received, paymentType: paymentType)
            })
            present(alert, animated: true)
        } catch {
            errorLabel.text = error.localizedDescription
            errorLabel.isHidden = false
            presentErrorAlert(error)
        }
    }

    private func submitSale(laptop: Laptop, name: String, phone: String, salePrice: Decimal, discount: Decimal, received: Decimal, paymentType: PaymentType) {
        confirmButton.isEnabled = false
        Task {
            do {
                // SRS 8.2: find the existing customer by phone, or create
                // one if this is their first purchase — never create a
                // second record for a phone number that's already on file.
                let customer = try await CustomerService.shared.findOrCreate(name: name, phone: phone)
                let request = NewSaleRequest(
                    customer: customer.id, laptopId: laptop.id, quantity: 1, salePrice: salePrice,
                    discountAmount: discount, discountPercent: 0, paymentType: paymentType,
                    amountReceived: received, notes: nil
                )
                let sale = try await SalesService.shared.create(request)
                await MainActor.run {
                    let bill = BillPreviewViewController(sale: sale, laptop: laptop, customerName: name, customerPhone: customer.phone, customerAddress: customer.address)
                    self.navigationController?.pushViewController(bill, animated: true)
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
            await MainActor.run { self.confirmButton.isEnabled = true }
        }
    }
}
