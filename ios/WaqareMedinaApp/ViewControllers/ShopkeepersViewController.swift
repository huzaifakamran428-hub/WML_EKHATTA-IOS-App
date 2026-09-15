import UIKit

/// Screen 10 — SRS 4.7: separate shopkeeper list and search. Lists real
/// shopkeeper accounts (one row per shopkeeper, not one per laptop) --
/// tapping a row opens their combined bill/account where laptops and
/// payments are added.
final class ShopkeepersViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    private let tableView = UITableView()
    private let searchController = UISearchController(searchResultsController: nil)
    private var shopkeepers: [Shopkeeper] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Shopkeepers"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ShopkeeperCell.self, forCellReuseIdentifier: ShopkeeperCell.reuseId)
        tableView.rowHeight = 64
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
        searchController.searchBar.placeholder = "Search name, phone, account no."
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        if AppState.shared.isAdmin {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addShopkeeper))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    private func load(search: String? = nil) {
        Task {
            do {
                let results = try await ShopkeeperService.shared.list(search: search)
                await MainActor.run {
                    self.shopkeepers = results
                    self.tableView.reloadData()
                    self.tableView.backgroundView = results.isEmpty ? EmptyStateView(message: "No shopkeepers found.") : nil
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        load(search: searchController.searchBar.text)
    }

    @objc private func addShopkeeper() {
        navigationController?.pushViewController(AddShopkeeperViewController(), animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { shopkeepers.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ShopkeeperCell.reuseId, for: indexPath) as! ShopkeeperCell
        cell.configure(with: shopkeepers[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = ShopkeeperDetailViewController(shopkeeperId: shopkeepers[indexPath.row].id)
        navigationController?.pushViewController(vc, animated: true)
    }
}
