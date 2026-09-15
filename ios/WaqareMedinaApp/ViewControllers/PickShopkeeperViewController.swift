import UIKit

/// Lightweight shopkeeper picker used only when the admin creates a
/// SHOPKEEPER-role login and needs to say which shopkeeper it belongs to.
final class PickShopkeeperViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    var onPicked: ((Shopkeeper) -> Void)?

    private let tableView = UITableView()
    private let searchController = UISearchController(searchResultsController: nil)
    private var shopkeepers: [Shopkeeper] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Shopkeeper"
        view.backgroundColor = .systemBackground
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
        searchController.searchBar.placeholder = "Search shopkeepers"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        load()
    }

    private func load(search: String? = nil) {
        Task {
            do {
                let results = try await ShopkeeperService.shared.list(search: search)
                await MainActor.run {
                    self.shopkeepers = results
                    self.tableView.reloadData()
                    self.tableView.backgroundView = results.isEmpty ? EmptyStateView(message: "No shopkeepers found. Add one first from the Shopkeepers tab.") : nil
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        load(search: searchController.searchBar.text)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { shopkeepers.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ShopkeeperCell.reuseId, for: indexPath) as! ShopkeeperCell
        cell.configure(with: shopkeepers[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let picked = shopkeepers[indexPath.row]
        onPicked?(picked)
        navigationController?.popViewController(animated: true)
    }
}
