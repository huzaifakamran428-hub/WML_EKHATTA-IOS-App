import UIKit

/// SRS 4.4: searchable inventory list; low-stock / out-of-stock marking.
final class LaptopCell: UITableViewCell {
    static let reuseId = "LaptopCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: LaptopCell.reuseId)
        accessoryType = .disclosureIndicator
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with laptop: Laptop) {
        var text = "\(laptop.brand) \(laptop.modelName)"
        if laptop.isOutOfStock {
            text += "  •  Out of stock"
            textLabel?.textColor = .systemRed
        } else if laptop.isLowStock {
            text += "  •  Low stock (\(laptop.quantity))"
            textLabel?.textColor = .systemOrange
        } else {
            text += "  •  \(laptop.quantity) in stock"
            textLabel?.textColor = .label
        }
        textLabel?.text = text
        detailTextLabel?.text = "\(laptop.processor) · \(laptop.ram) · \(laptop.storage) · \(CurrencyFormatter.format(laptop.finalPrice))"
    }
}
