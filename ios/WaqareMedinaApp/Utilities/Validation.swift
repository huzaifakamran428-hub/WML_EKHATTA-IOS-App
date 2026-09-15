import Foundation

/// SRS 17: 'Missing required fields show an actionable message such as:
/// "Please enter the customer name."'
enum ValidationError: Error, LocalizedError {
    case emptyField(String)
    case invalidPhone
    case invalidAmount
    case paymentExceedsRemaining

    var errorDescription: String? {
        switch self {
        case .emptyField(let field): return "Please enter the \(field)."
        case .invalidPhone: return "Please enter a valid phone number."
        case .invalidAmount: return "Please enter a valid amount."
        case .paymentExceedsRemaining: return "Payment amount cannot be greater than the remaining amount."
        }
    }
}

enum Validator {
    static func requireNonEmpty(_ value: String?, fieldName: String) throws -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ValidationError.emptyField(fieldName)
        }
        return value
    }

    static func requirePositiveDecimal(_ text: String?, fieldName: String) throws -> Decimal {
        guard let text = text, let value = Decimal(string: text), value > 0 else {
            throw ValidationError.emptyField(fieldName)
        }
        return value
    }

    /// SRS 4.9 / 17: client-side pre-check mirroring
    /// business_rules.validate_new_payment — the backend remains
    /// authoritative (SRS 3.3).
    static func validatePayment(amount: Decimal, remaining: Decimal) throws {
        guard amount > 0 else { throw ValidationError.invalidAmount }
        guard amount <= remaining else { throw ValidationError.paymentExceedsRemaining }
    }
}
