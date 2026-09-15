import UIKit

/// SRS 4.7 / 6.1: customer sales list cell.
final class SaleCell: UITableViewCell {
    static let reuseId = "SaleCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: SaleCell.reuseId)
        accessoryType = .disclosureIndicator
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with sale: Sale, customerName: String) {
        textLabel?.text = "Receipt #\(sale.receiptNo) — \(customerName)"
        detailTextLabel?.text = "\(CurrencyFormatter.format(sale.finalTotal)) · \(sale.paymentStatus.displayText) · \(AppDateFormat.displayString(fromAPIDate: sale.saleDate))"
    }
}
