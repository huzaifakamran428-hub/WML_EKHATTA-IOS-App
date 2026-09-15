import UIKit

/// Screen 2 — SRS 4.2 (Dashboard): stock, sales, profit, outstanding
/// balances and alerts; tap-through navigation to detail screens.
final class DashboardViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let cardsStack = UIStackView()
    private var inventoryCard: DashboardCardView!
    private var lowStockCard: DashboardCardView!
    private var outstandingCard: DashboardCardView!
    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Dashboard"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "bell"), style: .plain, target: self, action: #selector(openNotifications)
        )
        setupLayout()
        refreshControl.addTarget(self, action: #selector(loadData), for: .valueChanged)
        scrollView.refreshControl = refreshControl
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
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

        cardsStack.axis = .vertical
        cardsStack.spacing = 12
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(cardsStack)
        NSLayoutConstraint.activate([
            cardsStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            cardsStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            cardsStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            cardsStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            cardsStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])

        inventoryCard = DashboardCardView(title: "Total Laptops in Stock", value: "—")
        inventoryCard.onTap = { [weak self] in self?.pushInventory() }

        lowStockCard = DashboardCardView(title: "Low Stock Items", value: "—")
        lowStockCard.onTap = { [weak self] in self?.pushInventory(lowStockOnly: true) }

        outstandingCard = DashboardCardView(title: "Total Outstanding Payments", value: "—")
        outstandingCard.onTap = { [weak self] in self?.pushShopkeepers() }

        [inventoryCard, lowStockCard, outstandingCard].forEach { cardsStack.addArrangedSubview($0) }
    }

    @objc private func loadData() {
        Task {
            async let inventory = try? ReportService.shared.inventoryReport()
            async let outstanding = try? ReportService.shared.outstandingReport()
            let (inv, out) = await (inventory, outstanding)
            await MainActor.run {
                if let inv = inv {
                    self.inventoryCard.update(value: "\(inv.totalUnits)")
                    self.lowStockCard.update(value: "\(inv.lowStockCount)")
                }
                if let out = out {
                    self.outstandingCard.update(value: "Rs. \(out.totalOutstanding)")
                }
                self.refreshControl.endRefreshing()
            }
        }
    }

    private func pushInventory(lowStockOnly: Bool = false) {
        let vc = InventoryViewController()
        vc.initialLowStockFilter = lowStockOnly
        navigationController?.pushViewController(vc, animated: true)
    }

    private func pushShopkeepers() {
        navigationController?.pushViewController(ShopkeepersViewController(), animated: true)
    }

    @objc private func openNotifications() {
        navigationController?.pushViewController(NotificationsViewController(), animated: true)
    }
}
