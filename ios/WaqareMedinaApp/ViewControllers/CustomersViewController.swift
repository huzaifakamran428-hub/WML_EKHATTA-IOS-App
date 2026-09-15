import UIKit

/// Screen 8 — SRS 4.7: separate customer sales/bills list and search.
final class CustomersViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    private let tableView = UITableView()
    private let searchController = UISearchController(searchResultsController: nil)
    private var sales: [Sale] = []
    private var customerNames: [Int: String] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Customers"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SaleCell.self, forCellReuseIdentifier: SaleCell.reuseId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        // SRS 6.1: full name, laptop name/model, generation/specs, receipt #, phone, sale date
        searchController.searchBar.placeholder = "Search name, laptop, receipt #, phone"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Receipt #", style: .plain, target: self, action: #selector(openReceiptSearch)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    private func load(search: String? = nil) {
        Task {
            do {
                let results = try await SalesService.shared.list(search: search)
                let names = try await CustomerService.shared.list()
                await MainActor.run {
                    self.sales = results
                    self.customerNames = Dictionary(uniqueKeysWithValues: names.map { ($0.id, $0.name) })
                    self.tableView.reloadData()
                    self.tableView.backgroundView = results.isEmpty ? EmptyStateView(message: "No customer sales found.") : nil
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        load(search: searchController.searchBar.text)
    }

    @objc private func openReceiptSearch() {
        navigationController?.pushViewController(ReceiptSearchViewController(), animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sales.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SaleCell.reuseId, for: indexPath) as! SaleCell
        let sale = sales[indexPath.row]
        cell.configure(with: sale, customerName: customerNames[sale.customer] ?? "Customer")
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let sale = sales[indexPath.row]
        let vc = CustomerSaleDetailsViewController(sale: sale, customerName: customerNames[sale.customer] ?? "Customer")
        navigationController?.pushViewController(vc, animated: true)
    }
}
