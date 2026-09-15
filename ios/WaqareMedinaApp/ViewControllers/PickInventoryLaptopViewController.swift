import UIKit

/// "Add another laptop" for a shopkeeper is picked from shop Inventory --
/// never typed in manually -- so specs stay accurate and giving one to a
/// shopkeeper reduces the shop's own stock/low-stock tracking correctly.
/// Out-of-stock items are shown but disabled since there's nothing left
/// to give out.
final class PickInventoryLaptopViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    var onPicked: ((Laptop) -> Void)?

    private let tableView = UITableView()
    private let searchController = UISearchController(searchResultsController: nil)
    private var laptops: [Laptop] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Laptop from Inventory"
        view.backgroundColor = .systemBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LaptopCell.self, forCellReuseIdentifier: LaptopCell.reuseId)
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
        searchController.searchBar.placeholder = "Search brand, model, generation..."
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        load()
    }

    private func load(search: String? = nil) {
        Task {
            do {
                let results = try await InventoryService.shared.list(search: search)
                await MainActor.run {
                    self.laptops = results
                    self.tableView.reloadData()
                    self.tableView.backgroundView = results.isEmpty
                        ? EmptyStateView(message: "No laptops in Inventory. Add laptops from the Inventory tab first.")
                        : nil
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        load(search: searchController.searchBar.text)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { laptops.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LaptopCell.reuseId, for: indexPath) as! LaptopCell
        let laptop = laptops[indexPath.row]
        cell.configure(with: laptop)
        cell.selectionStyle = laptop.isOutOfStock ? .none : .default
        cell.isUserInteractionEnabled = true // keep row visible/scrollable; block via didSelect instead
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let laptop = laptops[indexPath.row]
        guard !laptop.isOutOfStock else {
            tableView.deselectRow(at: indexPath, animated: true)
            let alert = UIAlertController(
                title: "Out of Stock",
                message: "There are no \(laptop.brand) \(laptop.modelName) units left in Inventory to give out.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        onPicked?(laptop)
        navigationController?.popViewController(animated: true)
    }
}
