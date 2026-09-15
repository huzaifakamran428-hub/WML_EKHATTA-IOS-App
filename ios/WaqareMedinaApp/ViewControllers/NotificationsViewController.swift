import UIKit

/// Screen 14 — SRS 4.11 / 10: low-stock, due and overdue notifications.
final class NotificationsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private var notifications: [AppNotification] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Notifications"
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
        load()
    }

    private func load() {
        Task {
            do {
                let results = try await NotificationService.shared.list()
                await MainActor.run {
                    self.notifications = results
                    self.tableView.reloadData()
                    self.tableView.backgroundView = results.isEmpty ? EmptyStateView(message: "No notifications yet.") : nil
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { notifications.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let notif = notifications[indexPath.row]
        cell.textLabel?.text = (notif.isUnread ? "● " : "") + notif.title
        cell.textLabel?.font = .systemFont(ofSize: 15, weight: notif.isUnread ? .semibold : .regular)
        cell.detailTextLabel?.text = notif.message
        cell.detailTextLabel?.numberOfLines = 2
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let notif = notifications[indexPath.row]
        Task {
            try? await NotificationService.shared.markRead(id: notif.id)
            await MainActor.run { self.load() }
        }
    }
}
