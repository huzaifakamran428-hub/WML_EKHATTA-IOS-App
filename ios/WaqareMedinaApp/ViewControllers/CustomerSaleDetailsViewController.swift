import UIKit

/// Screen 9 — SRS 4.7 / 6.3: complete customer sale and receipt record.
final class CustomerSaleDetailsViewController: UIViewController {
    private var sale: Sale
    private let customerName: String
    private var laptop: Laptop?

    private let stack = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    init(sale: Sale, customerName: String) {
        self.sale = sale
        self.customerName = customerName
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Receipt #\(sale.receiptNo)"

        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
        ])

        rebuild()
        loadLaptop()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Picking this screen back up after an edit -- re-fetch so the
        // figures shown (and the bill, if opened again) reflect the change.
        reloadSale()
    }

    /// SRS 6.3: this screen (and the bill it generates) needs the laptop
    /// this sale was actually made against, not just its numeric id --
    /// previously this was only ever available right after *creating* the
    /// sale (passed in from NewSaleViewController), so re-opening an
    /// older receipt from the Customer section showed a bill with no
    /// laptop details at all. Fetch it here so both cases behave the same.
    private func loadLaptop() {
        guard let productId = sale.items.first?.product else { return }
        loadingIndicator.startAnimating()
        Task {
            let result = try? await InventoryService.shared.detail(id: productId)
            await MainActor.run {
                self.laptop = result
                self.loadingIndicator.stopAnimating()
                self.rebuild()
            }
        }
    }

    private func reloadSale() {
        Task {
            guard let fresh = try? await SalesService.shared.findByReceipt(sale.receiptNo) else { return }
            await MainActor.run {
                self.sale = fresh
                self.rebuild()
            }
        }
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let rows: [(String, String)] = [
            ("Customer", customerName),
            ("Receipt No.", sale.receiptNo),
            ("Sale Date", AppDateFormat.displayString(fromAPIDate: sale.saleDate)),
            ("Sale Price", CurrencyFormatter.format(sale.salePrice)),
            ("Discount", CurrencyFormatter.format(sale.discountAmount)),
            ("Final Total", CurrencyFormatter.format(sale.finalTotal)),
            ("Amount Received", CurrencyFormatter.format(sale.amountReceived)),
            ("Remaining", CurrencyFormatter.format(sale.remainingAmount)),
            ("Payment Status", sale.paymentStatus.displayText),
            ("Payment Type", sale.paymentType.rawValue.capitalized),
        ]
        for (label, value) in rows {
            let row = UIStackView()
            row.distribution = .fillEqually
            let l = UILabel(); l.text = label; l.font = .systemFont(ofSize: 14, weight: .medium); l.textColor = .secondaryLabel
            let v = UILabel(); v.text = value; v.font = .systemFont(ofSize: 15)
            row.addArrangedSubview(l); row.addArrangedSubview(v)
            stack.addArrangedSubview(row)
        }

        let viewBillButton = UIButton(type: .system)
        viewBillButton.setTitle("View / Share Bill", for: .normal)
        viewBillButton.addTarget(self, action: #selector(viewBill), for: .touchUpInside)
        stack.addArrangedSubview(viewBillButton)

        // SRS 11 / SRS 2: only ADMIN can edit or delete a recorded sale
        // (Read-Only stays view-only, enforced again server-side either way).
        if AppState.shared.isAdmin {
            let editButton = UIButton(type: .system)
            editButton.setTitle("Edit Bill", for: .normal)
            editButton.addTarget(self, action: #selector(editSale), for: .touchUpInside)
            stack.addArrangedSubview(editButton)

            let deleteButton = UIButton(type: .system)
            deleteButton.setTitle("Delete Bill", for: .normal)
            deleteButton.setTitleColor(.systemRed, for: .normal)
            deleteButton.addTarget(self, action: #selector(confirmDelete), for: .touchUpInside)
            stack.addArrangedSubview(deleteButton)
        }
    }

    @objc private func viewBill() {
        let vc = BillPreviewViewController(sale: sale, laptop: laptop, customerName: customerName)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func editSale() {
        let vc = EditSaleViewController(sale: sale, laptop: laptop)
        vc.onSaved = { [weak self] updated in
            self?.sale = updated
            self?.rebuild()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func confirmDelete() {
        let alert = UIAlertController(
            title: "Delete Bill?",
            message: "Delete receipt #\(sale.receiptNo)? The sold unit(s) will be returned to inventory stock. This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDelete()
        })
        present(alert, animated: true)
    }

    private func performDelete() {
        Task {
            do {
                try await SalesService.shared.delete(id: sale.id)
                await MainActor.run { self.navigationController?.popViewController(animated: true) }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }
}
