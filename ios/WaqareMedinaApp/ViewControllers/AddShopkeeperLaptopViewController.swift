import UIKit

/// "Add another laptop" -- SRS 9 extension per owner request: laptops
/// given to a shopkeeper are picked from shop Inventory, never typed in
/// manually. Every spec (brand/model/generation/RAM/storage/condition) is
/// copied in and shown read-only; only Price is editable, since the rate
/// given to this shopkeeper differs from the shop's own sale price.
/// Saving here never creates a new shopkeeper or a new bill -- it always
/// attaches to the existing `shopkeeper` passed in.
final class AddShopkeeperLaptopViewController: UIViewController {
    private let shopkeeperId: Int
    private let existingItem: ShopkeeperLaptopItem? // non-nil when correcting a price on an already-added laptop
    var onSaved: (() -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private let selectLaptopButton = UIButton(type: .system)
    private let specsCard = Theme.cardView()
    private let specsLabel = UILabel()
    private let priceField = FormTextField(label: "Price for this Shopkeeper (Rs.)", placeholder: "e.g. 48000", keyboardType: .decimalPad)
    private let saveButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    private var selectedLaptop: Laptop?

    init(shopkeeperId: Int, editingItem: ShopkeeperLaptopItem? = nil) {
        self.shopkeeperId = shopkeeperId
        self.existingItem = editingItem
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingItem == nil ? "Add Another Laptop" : "Edit Price"
        view.backgroundColor = .systemBackground
        setupLayout()

        if let existingItem {
            // Correcting price on an already-added laptop -- specs are
            // fixed and shown read-only; picking a different Inventory
            // item isn't offered here.
            selectLaptopButton.isHidden = true
            specsLabel.text = "\(existingItem.specSummary)\n\(existingItem.specDetail)"
            priceField.text = "\(existingItem.price)"
        }

        Theme.stylePrimaryButton(saveButton, title: existingItem == nil ? "Add Laptop" : "Save Price")
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        selectLaptopButton.addTarget(self, action: #selector(pickFromInventory), for: .touchUpInside)
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])

        Theme.styleSecondaryButton(selectLaptopButton, title: "📦  Select Laptop from Inventory")

        specsCard.translatesAutoresizingMaskIntoConstraints = false
        specsLabel.numberOfLines = 0
        specsLabel.font = .systemFont(ofSize: 16)
        specsLabel.text = "No laptop selected yet."
        specsLabel.textColor = .secondaryLabel
        specsLabel.translatesAutoresizingMaskIntoConstraints = false
        specsCard.addSubview(specsLabel)
        NSLayoutConstraint.activate([
            specsLabel.topAnchor.constraint(equalTo: specsCard.topAnchor, constant: 16),
            specsLabel.leadingAnchor.constraint(equalTo: specsCard.leadingAnchor, constant: 16),
            specsLabel.trailingAnchor.constraint(equalTo: specsCard.trailingAnchor, constant: -16),
            specsLabel.bottomAnchor.constraint(equalTo: specsCard.bottomAnchor, constant: -16),
        ])

        Theme.styleLargeField(priceField.textField)
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.numberOfLines = 0

        [selectLaptopButton, specsCard, priceField, errorLabel, saveButton].forEach { stack.addArrangedSubview($0) }
    }

    @objc private func pickFromInventory() {
        let picker = PickInventoryLaptopViewController()
        picker.onPicked = { [weak self] laptop in
            guard let self else { return }
            self.selectedLaptop = laptop
            self.specsLabel.textColor = .label
            let specParts: [String?] = [laptop.generation, laptop.ram, laptop.storage, laptop.condition.displayText]
            self.specsLabel.text = """
            \(laptop.brand) \(laptop.modelName)
            \(specParts.compactMap { $0 }.joined(separator: " · "))
            Shop sale price: \(CurrencyFormatter.format(laptop.finalPrice))  ·  \(laptop.quantity) in stock
            """
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    @objc private func save() {
        errorLabel.text = nil
        guard let priceText = priceField.text, let price = Decimal(string: priceText), price > 0 else {
            errorLabel.text = "Enter a valid price."
            return
        }

        saveButton.isEnabled = false
        Task {
            do {
                if let existingItem {
                    _ = try await ShopkeeperService.shared.updateLaptop(id: existingItem.id, UpdateShopkeeperLaptopRequest(price: price))
                } else {
                    guard let selectedLaptop else {
                        await MainActor.run {
                            self.errorLabel.text = "Select a laptop from Inventory first."
                            self.saveButton.isEnabled = true
                        }
                        return
                    }
                    let request = NewShopkeeperLaptopRequest(shopkeeper: shopkeeperId, inventoryLaptop: selectedLaptop.id, price: price)
                    _ = try await ShopkeeperService.shared.addLaptop(request)
                }
                await MainActor.run {
                    self.onSaved?()
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.errorLabel.text = error.localizedDescription
                    self.saveButton.isEnabled = true
                }
            }
        }
    }
}
