import Foundation

/// SRS 4.12, 4.13, 16 (Reporting Requirements) — lightweight response
/// wrappers for the /api/reports/* endpoints. Each report's shape is
/// intentionally loose (dictionaries of primitives) since exact fields
/// depend on the finalized API contract (SRS 9: 'The exact API contract
/// should be finalized during backend implementation.')
struct SalesReport: Codable {
    let count: Int
    let totalSales: Decimal
    enum CodingKeys: String, CodingKey { case count; case totalSales = "total_sales" }
}

struct InventoryReport: Codable {
    let totalStockValue: Decimal
    let totalUnits: Int
    let lowStockCount: Int
    let outOfStockCount: Int
    enum CodingKeys: String, CodingKey {
        case totalStockValue = "total_stock_value"
        case totalUnits = "total_units"
        case lowStockCount = "low_stock_count"
        case outOfStockCount = "out_of_stock_count"
    }
}

struct OutstandingReport: Codable {
    let totalOutstanding: Decimal
    enum CodingKeys: String, CodingKey { case totalOutstanding = "total_outstanding" }
}

struct ProfitReport: Codable {
    let totalProfit: Decimal
    enum CodingKeys: String, CodingKey { case totalProfit = "total_profit" }
}

struct InvestmentReport: Codable {
    let totalInvestment: Decimal
    let laptops: Int
    enum CodingKeys: String, CodingKey { case totalInvestment = "total_investment"; case laptops }
}

struct PaymentsReport: Codable {
    let totalReceived: Decimal
    enum CodingKeys: String, CodingKey { case totalReceived = "total_received" }
}
