import Foundation

/// SRS 4.5 (Sales and Bill Generation), 6.1 (Customer Sales Search),
/// 6.3 (Receipt Search)
final class SalesService {
    static let shared = SalesService()
    private init() {}

    struct ListResponse: Decodable { let results: [Sale]; let count: Int }

    func list(search: String? = nil) async throws -> [Sale] {
        if let search = search, !search.isEmpty {
            let url = URL(string: APIEndpoint.sales.url.absoluteString + "?search=\(search)")!
            return try await APIClient.shared.rawList(url: url)
        }
        let response: ListResponse = try await APIClient.shared.request(.sales, method: .get)
        return response.results
    }

    func create(_ request: NewSaleRequest) async throws -> Sale {
        try await APIClient.shared.request(.sales, method: .post, body: request)
    }

    /// SRS 11: admin can correct a mis-entered bill after the fact.
    /// Note: this can only adjust the numbers on the sale itself
    /// (price/discount/quantity/payment/notes) — it can't swap which
    /// laptop the sale was made against.
    func update(id: Int, _ request: EditSaleRequest) async throws -> Sale {
        try await APIClient.shared.request(.sale(id), method: .patch, body: request)
    }

    /// SRS 11: deleting a sale reverses its effect on inventory
    /// server-side (the sold units are given back to stock).
    func delete(id: Int) async throws {
        _ = try await APIClient.shared.request(.sale(id), method: .delete) as EmptyResponse
    }

    /// SRS 6.3: 'searching 00025 directly finds Receipt No. 00025'
    func findByReceipt(_ receiptNo: String) async throws -> Sale {
        try await APIClient.shared.request(.receiptSearch(receiptNo), method: .get)
    }
}

/// Request body for PATCH /api/sales/{id}/ — a deliberately smaller set
/// of editable fields than NewSaleRequest (no `customer`, no `laptop_id`:
/// SaleSerializer.update ignores/rejects changing either of those).
struct EditSaleRequest: Codable {
    let quantity: Int
    let salePrice: Decimal
    let discountAmount: Decimal
    let discountPercent: Decimal
    let paymentType: PaymentType
    let amountReceived: Decimal
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case quantity, notes
        case salePrice = "sale_price"
        case discountAmount = "discount_amount"
        case discountPercent = "discount_percent"
        case paymentType = "payment_type"
        case amountReceived = "amount_received"
    }
}
