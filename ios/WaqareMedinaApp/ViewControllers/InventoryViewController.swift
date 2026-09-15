import UIKit

/// Screen 3 — SRS 4.4 (Inventory Management), 6.2 (Laptop Spec Search).
final class InventoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    private let tableView = UITableView()
    private let searchController = UISearchController(searchResultsController: nil)
    private var laptops: [Laptop] = []
    var initialLowStockFilter = false

    /// When set, this screen acts as a laptop *picker* instead of a
    /// browsing list: tapping a row calls this closure and pops back,
    /// rather than pushing the read-only LaptopDetailsViewController. Used
    /// by New Sale and New Credit Plan to let the user actually choose a
    /// laptop instead of just dead-ending on its details screen.
    var onLaptopSelected: ((Laptop) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = onLaptopSelected != nil ? "Select Laptop" : "Inventory"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LaptopCell.self, forCellReuseIdentifier: LaptopCell.reuseId)
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
        searchController.searchBar.placeholder = "Search brand, model, generation, spec, S/N"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        if AppState.shared.isAdmin, onLaptopSelected == nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .add, target: self, action: #selector(addLaptop)
            )
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    private func load(search: String? = nil) {
        Task {
            do {
                let results = try await InventoryService.shared.list(search: search, lowStockOnly: initialLowStockFilter)
                await MainActor.run {
                    self.laptops = results
                    self.tableView.reloadData()
                    self.tableView.backgroundView = results.isEmpty ? EmptyStateView(message: "No laptops found.") : nil
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        load(search: searchController.searchBar.text)
    }

    @objc private func addLaptop() {
        navigationController?.pushViewController(AddEditLaptopViewController(laptop: nil), animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { laptops.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LaptopCell.reuseId, for: indexPath) as! LaptopCell
        cell.configure(with: laptops[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let laptop = laptops[indexPath.row]
        if let onLaptopSelected = onLaptopSelected {
            onLaptopSelected(laptop)
            navigationController?.popViewController(animated: true)
            return
        }
        let vc = LaptopDetailsViewController(laptop: laptop)
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension UIViewController {
    /// Tapping anywhere outside a text field dismisses the keyboard.
    /// Without this, a long form's keyboard has no way to close once a
    /// field is focused — on smaller screens it can permanently cover
    /// fields and buttons below it (e.g. the fixed Save footer), leaving
    /// no way to finish the form. Call once from viewDidLoad.
    func enableTapToDismissKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardOnTap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboardOnTap() {
        view.endEditing(true)
    }
}
