import UIKit

/// Screen 16 — SRS 4.13, 16: selected report data and export actions
/// (PDF / CSV where practical, restricted to authorized users).
final class ReportDetailsViewController: UIViewController {
    private let reportKey: String
    private let reportTitle: String
    private let summaryLabel = UILabel()

    init(reportKey: String, reportTitle: String) {
        self.reportKey = reportKey
        self.reportTitle = reportTitle
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = reportTitle
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(exportTapped))

        summaryLabel.numberOfLines = 0
        summaryLabel.font = .systemFont(ofSize: 16)
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.text = "Loading…"
        view.addSubview(summaryLabel)
        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
        load()
    }

    private func load() {
        Task {
            do {
                let text: String
                switch reportKey {
                case "sales":
                    let r = try await ReportService.shared.salesReport()
                    text = "Total Sales: \(r.totalSales)\nCount: \(r.count)"
                case "inventory":
                    let r = try await ReportService.shared.inventoryReport()
                    text = "Stock Value: Rs. \(r.totalStockValue)\nUnits: \(r.totalUnits)\nLow Stock: \(r.lowStockCount)\nOut of Stock: \(r.outOfStockCount)"
                case "outstanding":
                    let r = try await ReportService.shared.outstandingReport()
                    text = "Total Outstanding: Rs. \(r.totalOutstanding)"
                case "profit":
                    let r = try await ReportService.shared.profitReport()
                    text = "Total Profit: Rs. \(r.totalProfit)"
                case "investment":
                    let r = try await ReportService.shared.investmentReport()
                    text = "Total Investment: Rs. \(r.totalInvestment)\nLaptops in Stock: \(r.laptops)"
                case "payments":
                    let r = try await ReportService.shared.paymentsReport()
                    text = "Total Received: Rs. \(r.totalReceived)"
                default:
                    text = "This report is available from the backend's /api/reports/\(reportKey)/ endpoint."
                }
                await MainActor.run { self.summaryLabel.text = text }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    @objc private func exportTapped() {
        // SRS 4.13/16: 'Reports support PDF and CSV/Excel export where
        // practical... Export operations must respect role permissions.'
        guard AppState.shared.isAdmin else {
            presentErrorAlert(APIError.forbidden)
            return
        }
        let text = summaryLabel.text ?? ""
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activity, animated: true)
    }
}
