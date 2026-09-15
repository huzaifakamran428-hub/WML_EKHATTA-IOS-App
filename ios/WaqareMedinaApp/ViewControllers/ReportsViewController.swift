import UIKit

/// Screen 15 — SRS 4.12, 4.13, 16: sales, investment, profit, inventory
/// and outstanding reports; admin-only (SRS 2).
final class ReportsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private let reportNames = [
        "Daily / Monthly Sales", "Profit Report", "Investment Report",
        "Inventory Report", "Outstanding Report", "Payment History Report",
    ]
    private let reportKeys = ["sales", "profit", "investment", "inventory", "outstanding", "payments"]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Reports"
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
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { reportNames.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = reportNames[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = ReportDetailsViewController(reportKey: reportKeys[indexPath.row], reportTitle: reportNames[indexPath.row])
        navigationController?.pushViewController(vc, animated: true)
    }
}
