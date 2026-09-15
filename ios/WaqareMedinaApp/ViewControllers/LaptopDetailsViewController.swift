import UIKit

/// Screen 4 — SRS 4.3: specifications, photo, stock and pricing.
final class LaptopDetailsViewController: UIViewController {
    private let laptop: Laptop
    private let stack = UIStackView()

    init(laptop: Laptop) {
        self.laptop = laptop
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "\(laptop.brand) \(laptop.modelName)"

        if AppState.shared.isAdmin {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(edit))
        }

        let rows: [(String, String)] = [
            ("Brand", laptop.brand),
            ("Model", laptop.modelName),
            ("Generation", laptop.generation ?? "—"),
            ("Processor", laptop.processor),
            ("CPU Cores", "\(laptop.cpuCores)"),
            ("RAM", laptop.ram),
            ("Storage", laptop.storage),
            ("GPU", laptop.gpu ?? "—"),
            ("Screen Size", laptop.screenSize ?? "—"),
            ("Condition", laptop.condition.displayText),
            ("Serial Number", laptop.serialNumber ?? "—"),
            ("Purchase Price", CurrencyFormatter.format(laptop.purchasePrice)),
            ("Sale Price", CurrencyFormatter.format(laptop.salePrice)),
            ("Final Price", CurrencyFormatter.format(laptop.finalPrice)),
            ("Quantity", "\(laptop.quantity)\(laptop.isLowStock ? "  ⚠️ Low stock" : "")"),
            ("Supplier", laptop.supplier ?? "—"),
            ("Warranty", laptop.warranty ?? "—"),
            ("Notes", laptop.notes ?? "—"),
        ]

        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
        ])

        for (label, value) in rows {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            let l = UILabel(); l.text = label; l.font = .systemFont(ofSize: 14, weight: .medium); l.textColor = .secondaryLabel
            let v = UILabel(); v.text = value; v.font = .systemFont(ofSize: 15); v.numberOfLines = 0
            row.addArrangedSubview(l); row.addArrangedSubview(v)
            stack.addArrangedSubview(row)
        }

        if AppState.shared.isAdmin {
            let sellButton = UIButton(type: .system)
            sellButton.setTitle("New Sale with this Laptop", for: .normal)
            sellButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
            sellButton.backgroundColor = .systemBlue
            sellButton.setTitleColor(.white, for: .normal)
            sellButton.layer.cornerRadius = 10
            sellButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
            sellButton.addTarget(self, action: #selector(startSale), for: .touchUpInside)
            stack.addArrangedSubview(sellButton)
        }
    }

    @objc private func edit() {
        navigationController?.pushViewController(AddEditLaptopViewController(laptop: laptop), animated: true)
    }

    @objc private func startSale() {
        navigationController?.pushViewController(NewSaleViewController(preselectedLaptop: laptop), animated: true)
    }
}
