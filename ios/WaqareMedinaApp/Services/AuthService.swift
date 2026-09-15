import Foundation

/// SRS 4.1 (Authentication and User Management), 3.3 (Services isolate
/// network calls from ViewControllers).
final class AuthService {
    static let shared = AuthService()
    private init() {}

    func login(username: String, password: String) async throws -> AppUser {
        struct Body: Encodable { let username: String; let password: String }
        let response: LoginResponse = try await APIClient.shared.request(
            .login, method: .post, body: Body(username: username, password: password), authorized: false
        )
        KeychainManager.shared.store(tokens: AuthTokens(access: response.access, refresh: response.refresh))
        AppState.shared.currentUser = response.user
        return response.user
    }

    func loginWithGoogle(idToken: String) async throws -> AppUser {
        struct Body: Encodable { let id_token: String }
        let response: LoginResponse = try await APIClient.shared.request(
            .googleLogin, method: .post, body: Body(id_token: idToken), authorized: false
        )
        KeychainManager.shared.store(tokens: AuthTokens(access: response.access, refresh: response.refresh))
        AppState.shared.currentUser = response.user
        return response.user
    }

    func loginWithApple(identityToken: String) async throws -> AppUser {
        struct Body: Encodable { let identity_token: String }
        let response: LoginResponse = try await APIClient.shared.request(
            .appleLogin, method: .post, body: Body(identity_token: identityToken), authorized: false
        )
        KeychainManager.shared.store(tokens: AuthTokens(access: response.access, refresh: response.refresh))
        AppState.shared.currentUser = response.user
        return response.user
    }

    func logout() async {
        struct Body: Encodable { let refresh: String? }
        let refresh = KeychainManager.shared.refreshToken
        _ = try? await APIClient.shared.request(.logout, method: .post, body: Body(refresh: refresh)) as EmptyResponse
        AppState.shared.signOut()
    }

    /// SRS 4.1: 'Handle token expiry/refresh and session expiration
    /// without crashing.' Called by APIClient on a 401.
    func refreshTokenIfPossible() async -> Bool {
        guard let refreshToken = KeychainManager.shared.refreshToken else { return false }
        struct Body: Encodable { let refresh: String }
        struct RefreshResponse: Decodable { let access: String }
        do {
            let response: RefreshResponse = try await APIClient.shared.request(
                .tokenRefresh, method: .post, body: Body(refresh: refreshToken), authorized: false
            )
            KeychainManager.shared.accessToken = response.access
            return true
        } catch {
            // The refresh token itself was rejected -- expired (idle too
            // long server-side per SESSION_INACTIVITY_TIMEOUT_MINUTES, or
            // its 14-day lifetime), blacklisted, or invalid. Either way
            // this is a real, involuntary session end: tell the app to
            // return to Login with an explanation rather than leaving the
            // user stuck on a screen that will now fail every request.
            AppState.shared.expireSession(reason: "Your session has expired. Please log in again.")
            return false
        }
    }
}
