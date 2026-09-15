import Foundation
import Security

/// SRS 3.1, 4.1, 13: 'Store authentication credentials/tokens securely in
/// iOS Keychain; never store passwords in plain text.'
final class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.waqaremedina.app.auth"

    private init() {}

    private enum Key: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        // Persists the logged-in user's profile (id/role/etc, never the
        // password) so the app can stay signed in across a full app
        // restart. Previously AppState.currentUser only lived in memory,
        // so force-quitting the app wiped it even though the tokens above
        // were still valid -- the app would then bounce back to Login and
        // ask to sign in again despite the session still being good
        // (owner-reported: "so I couldn't login again and again").
        case cachedUser = "cached_user"
    }

    var accessToken: String? {
        get { read(.accessToken) }
        set { newValue == nil ? delete(.accessToken) : save(.accessToken, value: newValue!) }
    }

    var refreshToken: String? {
        get { read(.refreshToken) }
        set { newValue == nil ? delete(.refreshToken) : save(.refreshToken, value: newValue!) }
    }

    /// The signed-in user's profile, cached only so the app can restore a
    /// session on launch without another network round trip -- never a
    /// password or credential. Cleared on logout/session expiry along
    /// with the tokens.
    var cachedUser: AppUser? {
        get {
            guard let json = read(.cachedUser), let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(AppUser.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                delete(.cachedUser)
                return
            }
            save(.cachedUser, value: json)
        }
    }

    func store(tokens: AuthTokens) {
        accessToken = tokens.access
        refreshToken = tokens.refresh
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
        cachedUser = nil
    }

    // MARK: - Low-level Keychain operations

    private func save(_ key: Key, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func read(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
