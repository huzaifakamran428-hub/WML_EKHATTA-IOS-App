import UIKit

/// Screen 12 — SRS 4.9: all payments for selected credit plan; history
/// remains visible after clearance.
final class PaymentHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let planId: Int
    private let tableView = UITableView()
    private var payments: [Payment] = []

    init(planId: Int) {
        self.planId = planId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Payment History"
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
                let results = try await PaymentService.shared.paymentHistory(creditPlanId: planId)
                await MainActor.run {
                    self.payments = results
                    self.tableView.reloadData()
                    self.tableView.backgroundView = results.isEmpty ? EmptyStateView(message: "No payments recorded yet.") : nil
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { payments.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let payment = payments[indexPath.row]
        cell.textLabel?.text = CurrencyFormatter.format(payment.amount)
        cell.detailTextLabel?.text = "\(AppDateFormat.displayString(fromAPIDate: payment.paymentDate)) · \(payment.method.rawValue.capitalized)"
        cell.selectionStyle = .none
        return cell
    }
}
