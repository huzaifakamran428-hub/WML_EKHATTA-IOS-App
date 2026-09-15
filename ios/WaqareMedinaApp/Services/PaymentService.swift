import Foundation

/// SRS 4.8-4.11 (Credit Plans, Payment Tracking, Installment Completion)
final class PaymentService {
    static let shared = PaymentService()
    private init() {}

    struct CreditPlanListResponse: Decodable { let results: [CreditPlan]; let count: Int }
    struct PaymentListResponse: Decodable { let results: [Payment]; let count: Int }

    func listCreditPlans(status: CreditPlanStatus? = nil, search: String? = nil) async throws -> [CreditPlan] {
        var query: [String] = []
        if let status = status { query.append("status=\(status.rawValue)") }
        if let search = search, !search.isEmpty { query.append("search=\(search)") }
        if !query.isEmpty {
            let url = URL(string: APIEndpoint.creditPlans.url.absoluteString + "?" + query.joined(separator: "&"))!
            return try await APIClient.shared.rawList(url: url)
        }
        let response: CreditPlanListResponse = try await APIClient.shared.request(.creditPlans, method: .get)
        return response.results
    }

    func createCreditPlan(_ form: CreditPlanFormData) async throws -> CreditPlan {
        try await APIClient.shared.request(.creditPlans, method: .post, body: form)
    }

    func creditPlanDetail(id: Int) async throws -> CreditPlan {
        try await APIClient.shared.request(.creditPlan(id), method: .get)
    }

    func paymentHistory(creditPlanId: Int) async throws -> [Payment] {
        let url = URL(string: APIEndpoint.payments.url.absoluteString + "?credit_plan=\(creditPlanId)")!
        return try await APIClient.shared.rawList(url: url)
    }

    /// SRS 4.9: Add Payment (+) action.
    func addPayment(_ request: NewPaymentRequest) async throws -> Payment {
        try await APIClient.shared.request(.payments, method: .post, body: request)
    }
}

struct CreditPlanFormData: Encodable {
    let shopkeeper: Int?
    let customer: Int?
    let laptop: Int
    let total_amount: Decimal
    let down_payment: Decimal
    let installment_amount: Decimal
    let due_date: String
    let notes: String?
}
