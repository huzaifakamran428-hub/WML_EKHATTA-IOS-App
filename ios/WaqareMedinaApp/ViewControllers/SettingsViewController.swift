import UIKit

/// Screen 19 — SRS 4.13: Store details, logo, phone and notification
/// preferences; entry point to StoreProfile / Users / AuditLog.
final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    // "Manage Users" and "Audit Log" are Admin-only (SRS 2: Read-Only
    // cannot view/export beyond permitted records). Store Profile and
    // Receipt Search stay visible to everyone, and Log Out (below) is
    // always available regardless of role.
    private lazy var items: [(String, () -> UIViewController)] = {
        var rows: [(String, () -> UIViewController)] = [
            ("Store Profile", { StoreProfileViewController() }),
        ]
        if AppState.shared.isAdmin {
            rows.append(("Manage Users", { UsersViewController() }))
            rows.append(("Audit Log", { AuditLogViewController() }))
        }
        rows.append(("Receipt Search", { ReceiptSearchViewController() }))
        return rows
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Settings"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let logoutButton = UIBarButtonItem(title: "Log Out", style: .plain, target: self, action: #selector(logout))
        logoutButton.tintColor = .systemRed
        navigationItem.rightBarButtonItem = logoutButton
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row].0
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(items[indexPath.row].1(), animated: true)
    }

    @objc private func logout() {
        Task {
            await AuthService.shared.logout()
            await MainActor.run {
                InactivityMonitor.shared.stop()
                guard let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate else { return }
                sceneDelegate.window?.rootViewController = SceneDelegate.makeLoginFlow()
            }
        }
    }
}
