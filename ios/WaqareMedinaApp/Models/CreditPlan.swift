import Foundation

/// SRS 4.8-4.11 (Shopkeeper/Customer Credit Records, Payments,
/// Installment Completion, Notifications), 7 (Credit Plan / Payment)
enum CreditPlanStatus: String, Codable {
    case active = "ACTIVE"
    case cleared = "CLEARED"

    var displayText: String {
        self == .cleared ? "ALL INSTALLMENTS CLEARED — PAID IN FULL" : "Active"
    }
}

struct CreditPlan: Codable, Equatable {
    let id: Int
    var shopkeeper: Int?
    var customer: Int?
    let personName: String?
    var laptop: Int
    var sale: Int?
    var totalAmount: Decimal
    var downPayment: Decimal
    var installmentAmount: Decimal
    var dueDate: String
    let status: CreditPlanStatus
    let clearedAt: String?
    var notes: String?
    let totalReceived: Decimal
    let remainingAmount: Decimal
    let isOverdue: Bool

    enum CodingKeys: String, CodingKey {
        case id, shopkeeper, customer, laptop, sale, notes, status
        case personName = "person_name"
        case totalAmount = "total_amount"
        case downPayment = "down_payment"
        case installmentAmount = "installment_amount"
        case dueDate = "due_date"
        case clearedAt = "cleared_at"
        case totalReceived = "total_received"
        case remainingAmount = "remaining_amount"
        case isOverdue = "is_overdue"
    }

    /// SRS 4.10: 'Add Payment (+) must disappear from the cleared credit
    /// detail screen.'
    var canAddPayment: Bool { status == .active && remainingAmount > 0 }
}

enum PaymentMethod: String, Codable, CaseIterable {
    case cash = "CASH"
    case bank = "BANK"
    case other = "OTHER"
}

struct Payment: Codable, Equatable {
    let id: Int
    let creditPlan: Int
    let amount: Decimal
    let paymentDate: String
    let method: PaymentMethod
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, method, note
        case creditPlan = "credit_plan"
        case paymentDate = "payment_date"
    }
}

/// Request body for POST /api/payments/ (SRS 4.9: Add Payment (+) action)
struct NewPaymentRequest: Codable {
    let creditPlan: Int
    let amount: Decimal
    let method: PaymentMethod
    let note: String?

    enum CodingKeys: String, CodingKey {
        case amount, method, note
        case creditPlan = "credit_plan"
    }
}
