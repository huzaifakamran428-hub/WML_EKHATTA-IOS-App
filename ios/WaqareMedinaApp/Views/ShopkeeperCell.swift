import UIKit

/// One row per shopkeeper account (not per laptop) -- shows the combined
/// remaining balance across every laptop they've taken.
final class ShopkeeperCell: UITableViewCell {
    static let reuseId = "ShopkeeperCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: ShopkeeperCell.reuseId)
        accessoryType = .disclosureIndicator
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with shopkeeper: Shopkeeper) {
        textLabel?.text = "\(shopkeeper.name)  ·  \(shopkeeper.referenceNumber)"
        textLabel?.font = .boldSystemFont(ofSize: 16)

        let laptopCount = shopkeeper.laptops.count
        let laptopText = "\(laptopCount) laptop\(laptopCount == 1 ? "" : "s")"

        if shopkeeper.status == .cleared {
            detailTextLabel?.text = "\(laptopText) · CLEARED · Rs. 0 remaining"
            detailTextLabel?.textColor = .systemGreen
        } else {
            detailTextLabel?.text = "\(laptopText) · \(CurrencyFormatter.format(shopkeeper.remainingAmount)) remaining"
            detailTextLabel?.textColor = .secondaryLabel
        }
    }
}
