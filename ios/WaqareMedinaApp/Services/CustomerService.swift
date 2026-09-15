import Foundation

final class CustomerService {
    static let shared = CustomerService()
    private init() {}

    struct ListResponse: Decodable { let results: [Customer]; let count: Int }

    func list(search: String? = nil) async throws -> [Customer] {
        if let search = search, !search.isEmpty {
            let url = URL(string: APIEndpoint.customers.url.absoluteString + "?search=\(search)")!
            return try await APIClient.shared.rawList(url: url)
        }
        let response: ListResponse = try await APIClient.shared.request(.customers, method: .get)
        return response.results
    }

    func create(name: String, phone: String, address: String?, notes: String?) async throws -> Customer {
        struct Body: Encodable { let name: String; let phone: String; let address: String?; let notes: String? }
        return try await APIClient.shared.request(.customers, method: .post, body: Body(name: name, phone: phone, address: address, notes: notes))
    }

    /// Finds an existing customer by exact phone number, if one exists.
    /// Callers (e.g. New Sale) should use this before `create(...)` so a
    /// repeat customer isn't duplicated into a new record on every sale.
    func findByPhone(_ phone: String) async throws -> Customer? {
        let customers = try await list(search: phone)
        return customers.first { $0.phone == phone }
    }

    /// Returns the existing customer matching `phone` if one exists,
    /// otherwise creates a new one. This is what New Sale (and any other
    /// "enter a customer" screen) should call, so the same phone number
    /// always maps to one Customer record over time.
    func findOrCreate(name: String, phone: String, address: String? = nil, notes: String? = nil) async throws -> Customer {
        if let existing = try await findByPhone(phone) {
            return existing
        }
        return try await create(name: name, phone: phone, address: address, notes: notes)
    }
}
