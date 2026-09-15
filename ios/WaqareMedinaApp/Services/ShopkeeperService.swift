import Foundation

/// A shopkeeper is created ONCE (`create`) and reused after that: every
/// later laptop goes through `addLaptop` (picked from Inventory, never
/// `create` again), every extra-money entry through `addExtraMoney`, and
/// every payment goes through `addPayment` against a specific target
/// (laptop or extra money) -- never a per-laptop shopkeeper/receipt.
final class ShopkeeperService {
    static let shared = ShopkeeperService()
    private init() {}

    struct ListResponse: Decodable { let results: [Shopkeeper]; let count: Int }

    func list(search: String? = nil) async throws -> [Shopkeeper] {
        if let search = search, !search.isEmpty {
            let url = URL(string: APIEndpoint.shopkeepers.url.absoluteString + "?search=\(search)")!
            return try await APIClient.shared.rawList(url: url)
        }
        let response: ListResponse = try await APIClient.shared.request(.shopkeepers, method: .get)
        return response.results
    }

    func get(id: Int) async throws -> Shopkeeper {
        try await APIClient.shared.request(.shopkeeper(id), method: .get)
    }

    /// Only ever called once per real-world shopkeeper. The UI should
    /// search existing shopkeepers first and offer "Add another laptop"
    /// on an existing match instead of calling this again.
    func create(name: String, phone: String, cnic: String?, address: String?, notes: String?) async throws -> Shopkeeper {
        struct Body: Encodable { let name: String; let phone: String; let cnic: String?; let address: String?; let notes: String? }
        return try await APIClient.shared.request(.shopkeepers, method: .post, body: Body(name: name, phone: phone, cnic: cnic, address: address, notes: notes))
    }

    /// "Add another laptop" -- picks an Inventory item (specs copied,
    /// stock reduced server-side) and attaches it with a shopkeeper-
    /// specific price to an EXISTING shopkeeper. Adds to the same
    /// combined bill; never creates a new shopkeeper or a new receipt.
    func addLaptop(_ request: NewShopkeeperLaptopRequest) async throws -> ShopkeeperLaptopItem {
        try await APIClient.shared.request(.shopkeeperLaptops, method: .post, body: request)
    }

    /// Correct an already-added laptop's price (specs are fixed once added).
    func updateLaptop(id: Int, _ request: UpdateShopkeeperLaptopRequest) async throws -> ShopkeeperLaptopItem {
        try await APIClient.shared.request(.shopkeeperLaptop(id), method: .patch, body: request)
    }

    /// Remove a laptop item from a shopkeeper's account entirely --
    /// restores the unit to Inventory server-side.
    func deleteLaptop(id: Int) async throws {
        _ = try await APIClient.shared.request(.shopkeeperLaptop(id), method: .delete) as EmptyResponse
    }

    /// "Add Extra Money 💵" -- cash on top of laptops, its own separate
    /// receipt line, rolled into the shopkeeper's one combined bill total.
    func addExtraMoney(_ request: NewShopkeeperExtraMoneyRequest) async throws -> ShopkeeperExtraMoney {
        try await APIClient.shared.request(.shopkeeperExtraMoneyList, method: .post, body: request)
    }

    func updateExtraMoney(id: Int, _ request: UpdateShopkeeperExtraMoneyRequest) async throws -> ShopkeeperExtraMoney {
        try await APIClient.shared.request(.shopkeeperExtraMoney(id), method: .patch, body: request)
    }

    func deleteExtraMoney(id: Int) async throws {
        _ = try await APIClient.shared.request(.shopkeeperExtraMoney(id), method: .delete) as EmptyResponse
    }

    /// One payment, always targeted at exactly one laptop or one
    /// extra-money entry (the "Extra Money / Laptop Payment" dropdown).
    func addPayment(_ request: NewShopkeeperPaymentRequest) async throws -> ShopkeeperPayment {
        try await APIClient.shared.request(.shopkeeperPayments, method: .post, body: request)
    }

    /// Correct an already-recorded payment's amount/method/note. The
    /// backend re-validates the new amount against that payment's own
    /// target's remaining balance (excluding this payment's own old amount).
    func updatePayment(id: Int, _ request: UpdateShopkeeperPaymentRequest) async throws -> ShopkeeperPayment {
        try await APIClient.shared.request(.shopkeeperPayment(id), method: .patch, body: request)
    }

    /// Remove a payment from a shopkeeper's account entirely.
    func deletePayment(id: Int) async throws {
        _ = try await APIClient.shared.request(.shopkeeperPayment(id), method: .delete) as EmptyResponse
    }

    /// Delete the whole shopkeeper account -- cascades to every laptop,
    /// extra-money entry, and payment recorded under it (backend:
    /// on_delete=CASCADE).
    func delete(id: Int) async throws {
        _ = try await APIClient.shared.request(.shopkeeper(id), method: .delete) as EmptyResponse
    }
}
