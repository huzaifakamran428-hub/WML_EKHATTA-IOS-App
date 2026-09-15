import Foundation

/// SRS 14: 'Currency formatting uses Pakistani Rupees (Rs.)'
enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f
    }()

    static func format(_ amount: Decimal) -> String {
        let number = amount as NSDecimalNumber
        let text = formatter.string(from: number) ?? "\(amount)"
        return "Rs. \(text)"
    }
}
