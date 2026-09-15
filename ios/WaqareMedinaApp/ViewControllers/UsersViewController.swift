import UIKit

/// Screen 17 — SRS 4.1 / 4.13: Admin creates/manages read-only users.
final class UsersViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private var users: [AppUser] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Users"
        tableView.dataSource = self
        tableView.delegate = self
        // Registering the bare UITableViewCell class always dequeues
        // .default-style cells, which have no visible detailTextLabel --
        // the role/active subtitle set below was silently never shown.
        // Subclassing isn't needed; just hand back a .subtitle-style cell
        // ourselves instead of relying on the register/dequeue default.
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addUser))
        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The list was only ever fetched once, in viewDidLoad. Creating a
        // user pushes AddEditUserViewController and pops back here without
        // this screen reloading, so a newly-created user (or an
        // activate/deactivate done elsewhere) never showed up until the
        // app was relaunched. Reload every time this screen is about to
        // be shown instead.
        load()
    }

    private func load() {
        Task {
            do {
                let results = try await UserService.shared.list()
                await MainActor.run {
                    self.users = results
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    @objc private func addUser() {
        navigationController?.pushViewController(AddEditUserViewController(), animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { users.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let user = users[indexPath.row]
        cell.textLabel?.text = user.displayName
        cell.detailTextLabel?.text = "\(user.role.rawValue) · \(user.isActive ? "Active" : "Deactivated")"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Rows aren't tappable (nothing to push to), but without this the
        // tapped row's selection highlight just stays on screen forever --
        // it looked like a permanently "stuck" gray row.
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let user = users[indexPath.row]

        let toggleAction = UIContextualAction(style: .normal, title: user.isActive ? "Deactivate" : "Activate") { [weak self] _, _, done in
            Task {
                try? await UserService.shared.setActive(id: user.id, active: !user.isActive)
                await MainActor.run { self?.load() }
                done(true)
            }
        }
        toggleAction.backgroundColor = user.isActive ? .systemRed : .systemGreen

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.confirmDelete(user: user, completion: done)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction, toggleAction])
    }

    private func confirmDelete(user: AppUser, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Delete \(user.displayName)?",
            message: "This permanently removes their login. This can't be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            Task {
                do {
                    try await UserService.shared.delete(id: user.id)
                    await MainActor.run {
                        self?.load()
                        completion(true)
                    }
                } catch {
                    await MainActor.run {
                        self?.presentErrorAlert(error)
                        completion(false)
                    }
                }
            }
        })
        present(alert, animated: true)
    }
}
