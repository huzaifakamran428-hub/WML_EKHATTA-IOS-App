import Foundation

/// SRS 4.5 (Sales and Bill Generation), 7 (Sale / Sale Item entities)
enum PaymentType: String, Codable, CaseIterable {
    case cash = "CASH"
    case bank = "BANK"
    case other = "OTHER"
}

enum PaymentStatus: String, Codable {
    case paid = "PAID"
    case partial = "PARTIAL"
    case due = "DUE"

    var displayText: String {
        switch self {
        case .paid: return "Paid"
        case .partial: return "Partial"
        case .due: return "Due"
        }
    }
}

struct SaleItem: Codable, Equatable {
    let id: Int
    let product: Int
    let purchaseCostSnapshot: Decimal
    let salePrice: Decimal
    let quantity: Int
    let profit: Decimal

    enum CodingKeys: String, CodingKey {
        case id, product, quantity, profit
        case purchaseCostSnapshot = "purchase_cost_snapshot"
        case salePrice = "sale_price"
    }
}

struct Sale: Codable, Equatable {
    let id: Int
    let receiptNo: String
    let customer: Int
    var salePrice: Decimal
    var discountAmount: Decimal
    var discountPercent: Decimal
    let finalTotal: Decimal
    var paymentType: PaymentType
    let paymentStatus: PaymentStatus
    var amountReceived: Decimal
    let remainingAmount: Decimal
    let saleDate: String
    var notes: String?
    let items: [SaleItem]

    enum CodingKeys: String, CodingKey {
        case id, customer, notes, items
        case receiptNo = "receipt_no"
        case salePrice = "sale_price"
        case discountAmount = "discount_amount"
        case discountPercent = "discount_percent"
        case finalTotal = "final_total"
        case paymentType = "payment_type"
        case paymentStatus = "payment_status"
        case amountReceived = "amount_received"
        case remainingAmount = "remaining_amount"
        case saleDate = "sale_date"
    }
}

/// Request body for POST /api/sales/ (SRS 8.2: Normal Sale Workflow)
struct NewSaleRequest: Codable {
    let customer: Int
    let laptopId: Int
    let quantity: Int
    let salePrice: Decimal
    let discountAmount: Decimal
    let discountPercent: Decimal
    let paymentType: PaymentType
    let amountReceived: Decimal
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case customer, quantity, notes
        case laptopId = "laptop_id"
        case salePrice = "sale_price"
        case discountAmount = "discount_amount"
        case discountPercent = "discount_percent"
        case paymentType = "payment_type"
        case amountReceived = "amount_received"
    }
}
