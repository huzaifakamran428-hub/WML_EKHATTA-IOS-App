import UIKit

/// Screen 11 — SRS 4.8-4.10: laptop, total, received, remaining, due
/// dates and status; + Add Payment action disappears once CLEARED.
final class CreditDetailsViewController: UIViewController {
    private let planId: Int
    private var plan: CreditPlan?
    private let stack = UIStackView()
    private let statusLabel = UILabel()
    private var addPaymentButton: UIButton?

    init(planId: Int) {
        self.planId = planId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Credit Plan"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "History", style: .plain, target: self, action: #selector(openHistory))

        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    private func load() {
        Task {
            do {
                let plan = try await PaymentService.shared.creditPlanDetail(id: planId)
                await MainActor.run {
                    self.plan = plan
                    self.render(plan)
                }
            } catch {
                await MainActor.run { self.presentErrorAlert(error) }
            }
        }
    }

    private func render(_ plan: CreditPlan) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // SRS 4.10: cleared screen displays Total Price, Total Received,
        // Remaining = Rs. 0 and final payment date; status shown prominently.
        statusLabel.text = plan.status.displayText
        statusLabel.font = .boldSystemFont(ofSize: 18)
        statusLabel.textColor = plan.status == .cleared ? .systemGreen : (plan.isOverdue ? .systemRed : .label)
        statusLabel.numberOfLines = 0
        stack.addArrangedSubview(statusLabel)

        let rows: [(String, String)] = [
            ("Person", plan.personName ?? "—"),
            ("Total Price", CurrencyFormatter.format(plan.totalAmount)),
            ("Total Received", CurrencyFormatter.format(plan.totalReceived)),
            ("Remaining", CurrencyFormatter.format(plan.remainingAmount)),
            ("Installment Amount", CurrencyFormatter.format(plan.installmentAmount)),
            ("Due Date", AppDateFormat.displayString(fromAPIDate: plan.dueDate)),
            ("Notes", plan.notes ?? "—"),
        ]
        for (label, value) in rows {
            let row = UIStackView()
            row.distribution = .fillEqually
            let l = UILabel(); l.text = label; l.font = .systemFont(ofSize: 14, weight: .medium); l.textColor = .secondaryLabel
            let v = UILabel(); v.text = value; v.font = .systemFont(ofSize: 15); v.numberOfLines = 0
            row.addArrangedSubview(l); row.addArrangedSubview(v)
            stack.addArrangedSubview(row)
        }

        // SRS 4.10: 'Add Payment (+) must disappear from the cleared
        // credit detail screen.'
        if plan.canAddPayment && AppState.shared.isAdmin {
            let button = UIButton(type: .system)
            button.setTitle("+ Add Payment", for: .normal)
            button.titleLabel?.font = .boldSystemFont(ofSize: 17)
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 10
            button.heightAnchor.constraint(equalToConstant: 46).isActive = true
            button.addTarget(self, action: #selector(addPayment), for: .touchUpInside)
            stack.addArrangedSubview(button)
            addPaymentButton = button
        } else {
            addPaymentButton = nil
        }
    }

    @objc private func addPayment() {
        guard let plan = plan else { return }
        let vc = AddPaymentViewController(plan: plan)
        vc.onSaved = { [weak self] in self?.load() }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openHistory() {
        navigationController?.pushViewController(PaymentHistoryViewController(planId: planId), animated: true)
    }
}
