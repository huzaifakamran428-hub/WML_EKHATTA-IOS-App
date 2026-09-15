import UIKit

/// Screen 23 — SRS 6: search results across supported customer/laptop
/// fields (combines the Customer Sales Search and Laptop Spec Search from
/// SRS 6.1/6.2 into one results screen for a top-level search bar).
final class GlobalSearchResultsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private var laptops: [Laptop] = []
    private var sales: [Sale] = []
    private let query: String

    init(query: String) {
        self.query = query
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Results for \"\(query)\""
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LaptopCell.self, forCellReuseIdentifier: LaptopCell.reuseId)
        tableView.register(SaleCell.self, forCellReuseIdentifier: SaleCell.reuseId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        search()
    }

    private func search() {
        Task {
            async let laptopResults = try? InventoryService.shared.list(search: query)
            async let saleResults = try? SalesService.shared.list(search: query)
            let (l, s) = await (laptopResults, saleResults)
            await MainActor.run {
                self.laptops = l ?? []
                self.sales = s ?? []
                self.tableView.reloadData()
                if self.laptops.isEmpty && self.sales.isEmpty {
                    self.tableView.backgroundView = EmptyStateView(message: "No results found.")
                } else {
                    self.tableView.backgroundView = nil
                }
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Laptops" : "Sales"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? laptops.count : sales.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: LaptopCell.reuseId, for: indexPath) as! LaptopCell
            cell.configure(with: laptops[indexPath.row])
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: SaleCell.reuseId, for: indexPath) as! SaleCell
            cell.configure(with: sales[indexPath.row], customerName: "Customer #\(sales[indexPath.row].customer)")
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            navigationController?.pushViewController(LaptopDetailsViewController(laptop: laptops[indexPath.row]), animated: true)
        } else {
            let sale = sales[indexPath.row]
            navigationController?.pushViewController(CustomerSaleDetailsViewController(sale: sale, customerName: "Customer #\(sale.customer)"), animated: true)
        }
    }
}
