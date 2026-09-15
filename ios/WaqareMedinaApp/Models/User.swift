import Foundation

/// SRS 2 (User Types), 7 (User entity), 4.1 (Authentication)
enum UserRole: String, Codable {
    case admin = "ADMIN"
    case readOnly = "READ_ONLY"
    /// Admin-created login limited to ONE shopkeeper's own account
    /// (read-only: their own laptops, payments and remaining balance).
    case shopkeeper = "SHOPKEEPER"
}

struct AppUser: Codable, Equatable {
    let id: Int
    let username: String
    let email: String
    let firstName: String?
    let lastName: String?
    let role: UserRole
    let phoneNumber: String?
    let isActive: Bool
    /// Set only for role == .shopkeeper: which Shopkeeper record this
    /// login is scoped to.
    let shopkeeper: Int?
    let shopkeeperName: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email, role, shopkeeper
        case firstName = "first_name"
        case lastName = "last_name"
        case phoneNumber = "phone_number"
        case isActive = "is_active"
        case shopkeeperName = "shopkeeper_name"
    }

    var isAdmin: Bool { role == .admin }
    var isShopkeeper: Bool { role == .shopkeeper }
    var displayName: String {
        // first_name/last_name come back from Django as "" (not null) when
        // unset, so [firstName, lastName].compactMap{$0} kept two empty
        // strings and joined them into a single space " " -- not .isEmpty,
        // so it never fell back to the username and rendered as an
        // invisible blank name in the Users list. Trim each part first so
        // "blank" is actually detected as blank.
        let name = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? username : name
    }
}

struct AuthTokens: Codable {
    let access: String
    let refresh: String
}

struct LoginResponse: Codable {
    let access: String
    let refresh: String
    let user: AppUser
}
