import XCTest
@testable import WaqareMedinaApp

/// SRS 19 (Testing Requirements): 'Swift unit tests for discount, final
/// price, profit, balance and inventory presentation/calculation
/// helpers.' Mirrors backend/tests/test_business_rules.py so the Swift
/// preview calculations (SRS 3.3) stay consistent with the backend's
/// authoritative business_rules.py.
final class BusinessRulesPreviewTests: XCTestCase {
    func testFinalPriceWithFixedDiscount() {
        let result = Laptop.previewFinalPrice(salePrice: 100_000, discountAmount: 5_000, discountPercent: 0)
        XCTAssertEqual(result, 95_000)
    }

    func testFinalPriceWithPercentDiscount() {
        let result = Laptop.previewFinalPrice(salePrice: 100_000, discountAmount: 0, discountPercent: 10)
        XCTAssertEqual(result, 90_000)
    }

    func testFinalPriceNeverNegative() {
        let result = Laptop.previewFinalPrice(salePrice: 1_000, discountAmount: 5_000, discountPercent: 0)
        XCTAssertEqual(result, 0) // SRS 11: discount cannot exceed price -> backend rejects; UI floors at 0
    }

    func testValidatorRejectsEmptyField() {
        XCTAssertThrowsError(try Validator.requireNonEmpty("", fieldName: "customer name")) { error in
            XCTAssertEqual(error.localizedDescription, "Please enter the customer name.")
        }
    }

    func testValidatorAcceptsTrimmedValue() throws {
        let value = try Validator.requireNonEmpty("  Ali  ", fieldName: "name")
        XCTAssertEqual(value, "Ali")
    }

    func testPaymentValidationRejectsOverpayment() {
        // SRS 4.9/17: 'Payment amount cannot be greater than the remaining amount.'
        XCTAssertThrowsError(try Validator.validatePayment(amount: 50_000, remaining: 30_000))
    }

    func testPaymentValidationAcceptsExactRemaining() throws {
        // SRS acceptance criteria #53: full remaining payment clears the plan.
        try Validator.validatePayment(amount: 30_000, remaining: 30_000)
    }

    func testCreditPlanCanAddPaymentReflectsClearedStatus() {
        // A CLEARED plan with 0 remaining must not allow another payment (SRS 4.10).
        let cleared = CreditPlan(
            id: 1, shopkeeper: 1, customer: nil, personName: "Test Shop", laptop: 1, sale: nil,
            totalAmount: 80_000, downPayment: 0, installmentAmount: 20_000, dueDate: "2026-10-10",
            status: .cleared, clearedAt: "2026-09-01T00:00:00Z", notes: nil,
            totalReceived: 80_000, remainingAmount: 0, isOverdue: false
        )
        XCTAssertFalse(cleared.canAddPayment)
    }

    func testCreditPlanCanAddPaymentWhenActive() {
        let active = CreditPlan(
            id: 2, shopkeeper: 1, customer: nil, personName: "Test Shop", laptop: 1, sale: nil,
            totalAmount: 80_000, downPayment: 0, installmentAmount: 20_000, dueDate: "2026-10-10",
            status: .active, clearedAt: nil, notes: nil,
            totalReceived: 30_000, remainingAmount: 50_000, isOverdue: false
        )
        XCTAssertTrue(active.canAddPayment)
    }

    func testCurrencyFormatting() {
        // SRS 14: 'Currency formatting uses Pakistani Rupees (Rs.)'
        XCTAssertEqual(CurrencyFormatter.format(80000), "Rs. 80,000")
    }
}
