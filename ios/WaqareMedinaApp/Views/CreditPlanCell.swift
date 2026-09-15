import UIKit

/// SRS 4.8-4.10: shopkeeper/customer credit plan row with status.
final class CreditPlanCell: UITableViewCell {
    static let reuseId = "CreditPlanCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: CreditPlanCell.reuseId)
        accessoryType = .disclosureIndicator
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with plan: CreditPlan) {
        textLabel?.text = plan.personName ?? "Unknown"
        if plan.status == .cleared {
            detailTextLabel?.text = "CLEARED · Rs. 0 remaining"
            detailTextLabel?.textColor = .systemGreen
        } else if plan.isOverdue {
            detailTextLabel?.text = "OVERDUE · \(CurrencyFormatter.format(plan.remainingAmount)) remaining"
            detailTextLabel?.textColor = .systemRed
        } else {
            detailTextLabel?.text = "\(CurrencyFormatter.format(plan.remainingAmount)) remaining · due \(AppDateFormat.displayString(fromAPIDate: plan.dueDate))"
            detailTextLabel?.textColor = .secondaryLabel
        }
    }
}
