import UIKit

/// Shopkeeper's combined account screen -- replaces the old per-laptop
/// CreditPlan detail for shopkeepers. Shows every laptop they've taken
/// under ONE bill/reference number, the combined total/received/
/// remaining, and (admin only) "Add another laptop" + "Add Payment"
/// actions. A SHOPKEEPER-role login sees the exact same layout for their
/// own account, minus the admin actions (read-only).
final class ShopkeeperDetailViewController: UIViewController {
    private let shopkeeperId: Int
    private var shopkeeper: Shopkeeper?

    private let scroll = UIScrollView()
    private let stack = UIStackView()

    init(shopkeeperId: Int) {
        self.shopkeeperId = shopkeeperId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Shopkeeper Account"

        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -30),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    private func load() {
        Task {
            do {
                let sk = try await ShopkeeperService.shared.get(id: shopkeeperId)
                await MainActor.run {
                    self.shopkeeper = sk
                    self.render(sk)
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    private func render(_ sk: Shopkeeper) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        stack.addArrangedSubview(headerCard(sk))
        stack.addArrangedSubview(totalsCard(sk))
        let canManage = AppState.shared.isAdmin

        stack.addArrangedSubview(sectionLabel("LAPTOPS (\(sk.laptops.count))"))
        if sk.laptops.isEmpty {
            stack.addArrangedSubview(EmptyStateView(message: "No laptops added yet."))
        } else {
            for item in sk.laptops { stack.addArrangedSubview(laptopRow(item, canManage: canManage)) }
        }

        if canManage {
            let addLaptopButton = UIButton(type: .system)
            Theme.stylePrimaryButton(addLaptopButton, title: "+ Add Another Laptop")
            addLaptopButton.addTarget(self, action: #selector(addLaptop), for: .touchUpInside)
            stack.addArrangedSubview(addLaptopButton)
        }

        stack.addArrangedSubview(sectionLabel("EXTRA MONEY 💵 (\(sk.extraMoney.count))"))
        if sk.extraMoney.isEmpty {
            stack.addArrangedSubview(EmptyStateView(message: "No extra money recorded yet."))
        } else {
            for entry in sk.extraMoney { stack.addArrangedSubview(extraMoneyRow(entry, canManage: canManage)) }
        }

        if canManage {
            let addExtraMoneyButton = UIButton(type: .system)
            Theme.styleSecondaryButton(addExtraMoneyButton, title: "💵  Add Extra Money")
            addExtraMoneyButton.addTarget(self, action: #selector(addExtraMoney), for: .touchUpInside)
            stack.addArrangedSubview(addExtraMoneyButton)
        }

        stack.addArrangedSubview(sectionLabel("PAYMENTS (\(sk.payments.count))"))
        if sk.payments.isEmpty {
            stack.addArrangedSubview(EmptyStateView(message: "No payments recorded yet."))
        } else {
            for payment in sk.payments { stack.addArrangedSubview(paymentRow(payment, canManage: canManage)) }
        }

        // SRS-style rule carried over from CreditPlan: Add Payment
        // disappears once the combined balance is fully cleared.
        if canManage && sk.canAddPayment {
            let addPaymentButton = UIButton(type: .system)
            Theme.stylePrimaryButton(addPaymentButton, title: "+ Add Payment")
            addPaymentButton.backgroundColor = Theme.accent
            addPaymentButton.addTarget(self, action: #selector(addPayment), for: .touchUpInside)
            stack.addArrangedSubview(addPaymentButton)
        }

        let billButton = UIButton(type: .system)
        Theme.styleSecondaryButton(billButton, title: "View / Share Combined Bill")
        billButton.addTarget(self, action: #selector(viewBill), for: .touchUpInside)
        stack.addArrangedSubview(billButton)

        if canManage {
            let deleteAccountButton = UIButton(type: .system)
            deleteAccountButton.setTitle("Delete Shopkeeper Account", for: .normal)
            deleteAccountButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
            deleteAccountButton.setTitleColor(.systemRed, for: .normal)
            deleteAccountButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
            deleteAccountButton.layer.cornerRadius = 14
            deleteAccountButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
            deleteAccountButton.addTarget(self, action: #selector(deleteAccount), for: .touchUpInside)
            stack.addArrangedSubview(deleteAccountButton)
        }
    }

    private func headerCard(_ sk: Shopkeeper) -> UIView {
        let card = Theme.cardView()
        let name = UILabel(); name.text = sk.name; name.font = .boldSystemFont(ofSize: 24)
        let ref = UILabel(); ref.text = "Account: \(sk.referenceNumber)"; ref.font = .systemFont(ofSize: 13, weight: .semibold); ref.textColor = .secondaryLabel
        let phone = UILabel(); phone.text = "Phone: \(sk.phone)"; phone.font = .systemFont(ofSize: 15); phone.textColor = .darkGray
        let pill = Theme.pillLabel(text: sk.status.displayText, color: sk.status == .cleared ? .systemGreen : Theme.accent)
        pill.setContentHuggingPriority(.required, for: .horizontal)

        let pillRow = UIStackView(arrangedSubviews: [pill, UIView()])
        pillRow.axis = .horizontal

        var rows: [UIView] = [name, ref, phone]
        if let address = sk.address, !address.isEmpty {
            let addressLabel = UILabel()
            addressLabel.text = "Address: \(address)"
            addressLabel.font = .systemFont(ofSize: 15)
            addressLabel.textColor = .darkGray
            addressLabel.numberOfLines = 0
            rows.append(addressLabel)
        }
        rows.append(pillRow)

        let inner = UIStackView(arrangedSubviews: rows)
        inner.axis = .vertical
        inner.spacing = 6
        inner.setCustomSpacing(10, after: rows[rows.count - 2])
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return card
    }

    private func totalsCard(_ sk: Shopkeeper) -> UIView {
        let card = Theme.cardView()
        card.backgroundColor = Theme.brand
        func row(_ label: String, _ value: String, big: Bool = false) -> UIStackView {
            let l = UILabel(); l.text = label; l.font = .systemFont(ofSize: 14, weight: .medium); l.textColor = UIColor.white.withAlphaComponent(0.75)
            let v = UILabel(); v.text = value; v.font = big ? .boldSystemFont(ofSize: 26) : .boldSystemFont(ofSize: 16); v.textColor = .white
            let row = UIStackView(arrangedSubviews: [l, v])
            row.axis = .vertical
            row.spacing = 2
            return row
        }
        let inner = UIStackView(arrangedSubviews: [
            row("TOTAL AMOUNT (ALL LAPTOPS)", CurrencyFormatter.format(sk.totalAmount)),
            row("TOTAL RECEIVED", CurrencyFormatter.format(sk.totalReceived)),
            row("REMAINING BALANCE", CurrencyFormatter.format(sk.remainingAmount), big: true),
        ])
        inner.axis = .vertical
        inner.spacing = 14
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }

    private func laptopRow(_ item: ShopkeeperLaptopItem, canManage: Bool) -> UIView {
        let card = Theme.cardView()
        let refRow = UIStackView(arrangedSubviews: [
            { let l = UILabel(); l.text = item.itemReference; l.font = .systemFont(ofSize: 12, weight: .semibold); l.textColor = .secondaryLabel; return l }(),
            UIView(),
        ])
        if item.isCleared { refRow.addArrangedSubview(Theme.pillLabel(text: "Cleared", color: .systemGreen)) }
        let title = UILabel(); title.text = "\(item.brand) \(item.modelName)"; title.font = .boldSystemFont(ofSize: 17)
        let specParts = [item.coreGeneration, item.ram, item.storage, item.condition].compactMap { $0 }.filter { !$0.isEmpty }
        let spec = UILabel(); spec.text = specParts.joined(separator: " · "); spec.font = .systemFont(ofSize: 13); spec.textColor = .darkGray; spec.numberOfLines = 0
        let priceRow = UIStackView(arrangedSubviews: [
            makeAmountLabel("Price", CurrencyFormatter.format(item.price)),
            makeAmountLabel("Remaining", CurrencyFormatter.format(item.remainingAmount), color: item.remainingAmount > 0 ? .systemRed : .systemGreen),
        ])
        priceRow.distribution = .fillEqually

        var items: [UIView] = [refRow, title, spec, priceRow]
        if canManage {
            items.append(manageButtonsRow(
                onEdit: { [weak self] in self?.editLaptop(item) },
                onDelete: { [weak self] in self?.confirmDeleteLaptop(item) }
            ))
        }
        let inner = UIStackView(arrangedSubviews: items)
        inner.axis = .vertical
        inner.spacing = 6
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func extraMoneyRow(_ entry: ShopkeeperExtraMoney, canManage: Bool) -> UIView {
        let card = Theme.cardView()
        let refRow = UIStackView(arrangedSubviews: [
            { let l = UILabel(); l.text = "💵 \(entry.itemReference)"; l.font = .systemFont(ofSize: 12, weight: .semibold); l.textColor = .secondaryLabel; return l }(),
            UIView(),
        ])
        if entry.isCleared { refRow.addArrangedSubview(Theme.pillLabel(text: "Cleared", color: .systemGreen)) }
        let note = UILabel(); note.text = (entry.note?.isEmpty == false) ? entry.note : "Extra money"; note.font = .boldSystemFont(ofSize: 16); note.numberOfLines = 0
        let amountRow = UIStackView(arrangedSubviews: [
            makeAmountLabel("Amount", CurrencyFormatter.format(entry.amount)),
            makeAmountLabel("Remaining", CurrencyFormatter.format(entry.remainingAmount), color: entry.remainingAmount > 0 ? .systemRed : .systemGreen),
        ])
        amountRow.distribution = .fillEqually

        var items: [UIView] = [refRow, note, amountRow]
        if canManage {
            items.append(manageButtonsRow(
                onEdit: { [weak self] in self?.editExtraMoney(entry) },
                onDelete: { [weak self] in self?.confirmDeleteExtraMoney(entry) }
            ))
        }
        let inner = UIStackView(arrangedSubviews: items)
        inner.axis = .vertical
        inner.spacing = 6
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    /// Small "Edit" / "Delete" text-button row, shared by laptop and
    /// payment cards (admin only).
    private func manageButtonsRow(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> UIView {
        let editButton = UIButton(type: .system)
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = .boldSystemFont(ofSize: 13)
        editButton.addAction(UIAction { _ in onEdit() }, for: .touchUpInside)

        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("Delete", for: .normal)
        deleteButton.titleLabel?.font = .boldSystemFont(ofSize: 13)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.addAction(UIAction { _ in onDelete() }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [editButton, deleteButton, UIView()])
        row.axis = .horizontal
        row.spacing = 20
        return row
    }

    private func makeAmountLabel(_ label: String, _ value: String, color: UIColor = .label) -> UIView {
        let l = UILabel(); l.text = label; l.font = .systemFont(ofSize: 11, weight: .semibold); l.textColor = .secondaryLabel
        let v = UILabel(); v.text = value; v.font = .boldSystemFont(ofSize: 15); v.textColor = color
        let s = UIStackView(arrangedSubviews: [l, v])
        s.axis = .vertical
        s.spacing = 2
        return s
    }

    private func paymentRow(_ payment: ShopkeeperPayment, canManage: Bool) -> UIView {
        let card = Theme.cardView()
        let amount = UILabel(); amount.text = CurrencyFormatter.format(payment.amount); amount.font = .boldSystemFont(ofSize: 17)
        let targetText = paymentTargetLabel(payment)
        let target = UILabel(); target.text = targetText; target.font = .systemFont(ofSize: 13, weight: .medium); target.textColor = Theme.brand; target.numberOfLines = 0
        let meta = UILabel(); meta.text = "\(AppDateFormat.displayString(fromAPIDate: payment.paymentDate)) · \(payment.method.rawValue.capitalized)"; meta.font = .systemFont(ofSize: 13); meta.textColor = .secondaryLabel
        var items: [UIView] = [amount, target, meta]
        if let note = payment.note, !note.isEmpty {
            let noteLabel = UILabel(); noteLabel.text = "Note: \(note)"; noteLabel.font = .italicSystemFont(ofSize: 13); noteLabel.textColor = .secondaryLabel; noteLabel.numberOfLines = 0
            items.append(noteLabel)
        }
        if canManage {
            items.append(manageButtonsRow(
                onEdit: { [weak self] in self?.editPayment(payment) },
                onDelete: { [weak self] in self?.confirmDeletePayment(payment) }
            ))
        }
        let inner = UIStackView(arrangedSubviews: items)
        inner.axis = .vertical
        inner.spacing = 4
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        return card
    }

    /// "Clears: 💵 Extra Money" or "Clears: SK-00001-2 — Dell Latitude 5490"
    /// -- looked up from the already-loaded shopkeeper detail rather than
    /// another network call.
    private func paymentTargetLabel(_ payment: ShopkeeperPayment) -> String {
        guard let sk = shopkeeper else { return "" }
        if let laptopId = payment.laptopItem, let item = sk.laptops.first(where: { $0.id == laptopId }) {
            return "Clears: \(item.itemReference) — \(item.specSummary)"
        }
        if let extraId = payment.extraMoney, sk.extraMoney.first(where: { $0.id == extraId }) != nil {
            return "Clears: 💵 Extra Money"
        }
        return ""
    }

    @objc private func addLaptop() {
        let vc = AddShopkeeperLaptopViewController(shopkeeperId: shopkeeperId)
        vc.onSaved = { [weak self] in self?.load() }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func addExtraMoney() {
        guard let sk = shopkeeper else { return }
        let vc = AddShopkeeperExtraMoneyViewController(shopkeeper: sk)
        vc.onSaved = { [weak self] in self?.load() }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func editExtraMoney(_ entry: ShopkeeperExtraMoney) {
        guard let sk = shopkeeper else { return }
        let vc = AddShopkeeperExtraMoneyViewController(shopkeeper: sk, existingEntry: entry)
        vc.onSaved = { [weak self] in self?.load() }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func confirmDeleteExtraMoney(_ entry: ShopkeeperExtraMoney) {
        let alert = UIAlertController(
            title: "Delete Extra Money Entry?",
            message: "Remove this \(CurrencyFormatter.format(entry.amount)) extra money entry (\(entry.itemReference))? This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteExtraMoney(entry.id)
        })
        present(alert, animated: true)
    }

    private func performDeleteExtraMoney(_ id: Int) {
        Task {
            do {
                try await ShopkeeperService.shared.deleteExtraMoney(id: id)
                await MainActor.run { self.load() }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    @objc private func addPayment() {
        guard let sk = shopkeeper else { return }
        let vc = AddShopkeeperPaymentViewController(shopkeeper: sk)
        vc.onSaved = { [weak self] in self?.load() }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func viewBill() {
        guard let sk = shopkeeper else { return }
        navigationController?.pushViewController(BillPreviewViewController(shopkeeper: sk), animated: true)
    }

    private func editLaptop(_ item: ShopkeeperLaptopItem) {
        let vc = AddShopkeeperLaptopViewController(shopkeeperId: shopkeeperId, editingItem: item)
        vc.onSaved = { [weak self] in self?.load() }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func confirmDeleteLaptop(_ item: ShopkeeperLaptopItem) {
        let alert = UIAlertController(
            title: "Delete Laptop?",
            message: "Remove \(item.brand) \(item.modelName) (\(item.itemReference)) from this account? This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteLaptop(item.id)
        })
        present(alert, animated: true)
    }

    private func performDeleteLaptop(_ id: Int) {
        Task {
            do {
                try await ShopkeeperService.shared.deleteLaptop(id: id)
                await MainActor.run { self.load() }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    private func editPayment(_ payment: ShopkeeperPayment) {
        guard let sk = shopkeeper else { return }
        let vc = AddShopkeeperPaymentViewController(shopkeeper: sk, editingPayment: payment)
        vc.onSaved = { [weak self] in self?.load() }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func confirmDeletePayment(_ payment: ShopkeeperPayment) {
        let alert = UIAlertController(
            title: "Delete Payment?",
            message: "Remove the \(CurrencyFormatter.format(payment.amount)) payment recorded on \(AppDateFormat.displayString(fromAPIDate: payment.paymentDate))? This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeletePayment(payment.id)
        })
        present(alert, animated: true)
    }

    private func performDeletePayment(_ id: Int) {
        Task {
            do {
                try await ShopkeeperService.shared.deletePayment(id: id)
                await MainActor.run { self.load() }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    @objc private func deleteAccount() {
        guard let sk = shopkeeper else { return }
        let alert = UIAlertController(
            title: "Delete Shopkeeper Account?",
            message: "This permanently deletes \(sk.name)'s account (\(sk.referenceNumber)) along with all \(sk.laptops.count) laptop(s) and \(sk.payments.count) payment(s) recorded under it. This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete Account", style: .destructive) { [weak self] _ in
            self?.performDeleteAccount(sk.id)
        })
        present(alert, animated: true)
    }

    private func performDeleteAccount(_ id: Int) {
        Task {
            do {
                try await ShopkeeperService.shared.delete(id: id)
                await MainActor.run {
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    /// Only wired up when this screen is the shopkeeper's own-account root
    /// (see SceneDelegate.makeShopkeeperOwnAccountRoot) -- admins reach
    /// this screen via the Shopkeepers tab instead and use Settings to log out.
    @objc func logOutTapped() {
        Task {
            await AuthService.shared.logout()
            await MainActor.run {
                InactivityMonitor.shared.stop()
                guard let windowScene = self.view.window?.windowScene, let sceneDelegate = windowScene.delegate as? SceneDelegate else { return }
                sceneDelegate.window?.rootViewController = SceneDelegate.makeLoginFlow()
            }
        }
    }
}
