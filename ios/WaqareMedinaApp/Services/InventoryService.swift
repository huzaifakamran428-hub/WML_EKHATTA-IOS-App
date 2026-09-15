import Foundation

/// SRS 4.4 (Inventory Management), 6.2 (Laptop Specification Search)
final class InventoryService {
    static let shared = InventoryService()
    private init() {}

    struct ListResponse: Decodable { let results: [Laptop]; let count: Int }

    func list(search: String? = nil, lowStockOnly: Bool = false, includeArchived: Bool = false) async throws -> [Laptop] {
        var query: [String] = []
        if let search = search, !search.isEmpty { query.append("search=\(search)") }
        if lowStockOnly { query.append("low_stock=true") }
        if includeArchived { query.append("include_archived=true") }
        if !query.isEmpty {
            let url = URL(string: APIEndpoint.laptops.url.absoluteString + "?" + query.joined(separator: "&"))!
            return try await APIClient.shared.rawList(url: url)
        }
        let response: ListResponse = try await APIClient.shared.request(.laptops, method: .get)
        return response.results
    }

    func detail(id: Int) async throws -> Laptop {
        try await APIClient.shared.request(.laptop(id), method: .get)
    }

    func create(_ laptop: LaptopFormData) async throws -> Laptop {
        try await APIClient.shared.request(.laptops, method: .post, body: laptop)
    }

    func update(id: Int, _ laptop: LaptopFormData) async throws -> Laptop {
        try await APIClient.shared.request(.laptop(id), method: .patch, body: laptop)
    }

    func archive(id: Int) async throws {
        _ = try await APIClient.shared.request(.laptop(id), method: .delete) as EmptyResponse
    }
}

/// SRS 4.3: form payload for Add/Edit Laptop (photo optional, never
/// required to save).
struct LaptopFormData: Encodable {
    let brand: String
    let model_name: String
    let generation: String?
    let processor: String
    let cpu_cores: Int
    let ram: String
    let storage: String
    let gpu: String?
    let screen_size: String?
    let condition: LaptopCondition
    let serial_number: String?
    let purchase_price: Decimal
    let sale_price: Decimal
    let discount_amount: Decimal
    let discount_percent: Decimal
    let quantity: Int
    let supplier: String?
    let warranty: String?
    let notes: String?
}

/// Wraps a paginated `{ "results": [...] }` response for `rawList` below.
/// Kept at file scope (not nested inside `rawList`) because Swift doesn't
/// allow a generic type to be declared inside a generic function.
private struct RawListWrapper<Element: Decodable>: Decodable {
    let results: [Element]
}

extension APIClient {
    /// Helper for pre-built query URLs (search/filter) reused by several
    /// services; kept here to avoid duplicating URLRequest boilerplate.
    func rawList<T: Decodable>(url: URL) async throws -> [T] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = KeychainManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.unknown
        }
        return try JSONDecoder().decode(RawListWrapper<T>.self, from: data).results
    }
}
