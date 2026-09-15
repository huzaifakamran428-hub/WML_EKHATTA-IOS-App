import Foundation

/// SRS 4.12 (Profit and Sales Reports), 4.13, 16 (Reporting Requirements)
final class ReportService {
    static let shared = ReportService()
    private init() {}

    func salesReport(dateFrom: String? = nil, dateTo: String? = nil) async throws -> SalesReport {
        try await get(.reportSales, dateFrom: dateFrom, dateTo: dateTo)
    }

    func inventoryReport() async throws -> InventoryReport {
        try await APIClient.shared.request(.reportInventory, method: .get)
    }

    func outstandingReport() async throws -> OutstandingReport {
        try await APIClient.shared.request(.reportOutstanding, method: .get)
    }

    func profitReport(dateFrom: String? = nil, dateTo: String? = nil) async throws -> ProfitReport {
        try await get(.reportProfit, dateFrom: dateFrom, dateTo: dateTo)
    }

    func investmentReport() async throws -> InvestmentReport {
        try await APIClient.shared.request(.reportInvestment, method: .get)
    }

    func paymentsReport(dateFrom: String? = nil, dateTo: String? = nil) async throws -> PaymentsReport {
        try await get(.reportPayments, dateFrom: dateFrom, dateTo: dateTo)
    }

    private func get<T: Decodable>(_ endpoint: APIEndpoint, dateFrom: String?, dateTo: String?) async throws -> T {
        var query: [String] = []
        if let dateFrom = dateFrom { query.append("date_from=\(dateFrom)") }
        if let dateTo = dateTo { query.append("date_to=\(dateTo)") }
        var url = endpoint.url
        if !query.isEmpty {
            url = URL(string: url.absoluteString + "?" + query.joined(separator: "&"))!
        }
        var request = URLRequest(url: url)
        if let token = KeychainManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw APIError.unknown }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
