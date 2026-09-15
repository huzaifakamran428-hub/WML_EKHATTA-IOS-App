import Foundation

/// SRS 4.1 / 4.13: Admin creates/manages read-only users.
final class UserService {
    static let shared = UserService()
    private init() {}

    struct ListResponse: Decodable { let results: [AppUser]; let count: Int }

    func list() async throws -> [AppUser] {
        let response: ListResponse = try await APIClient.shared.request(.users, method: .get)
        return response.results
    }

    func create(username: String, email: String, password: String, role: UserRole, phone: String?, shopkeeperId: Int? = nil) async throws -> AppUser {
        struct Body: Encodable {
            let username: String; let email: String; let password: String
            let role: UserRole; let phone_number: String?; let shopkeeper: Int?
        }
        return try await APIClient.shared.request(.users, method: .post,
            body: Body(username: username, email: email, password: password, role: role, phone_number: phone, shopkeeper: shopkeeperId))
    }

    /// Permanently removes a user. The backend already exposes this via
    /// the standard ModelViewSet DELETE route (Admin-only, same
    /// permission as everything else on /api/users/) -- the app just
    /// never called it, so Deactivate was the only option available.
    func delete(id: Int) async throws {
        let url = APIConfig.baseURL.appendingPathComponent("users/\(id)/")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = KeychainManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.unknown
        }
    }

    /// SRS 4.1: 'Admin can activate/deactivate users.'
    func setActive(id: Int, active: Bool) async throws {
        let path = active ? "users/\(id)/activate/" : "users/\(id)/deactivate/"
        let url = APIConfig.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = KeychainManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.unknown
        }
    }
}
