import Foundation

/// App/session state shared across ViewControllers (SRS 3.3:
/// ViewControllers should not hold networking/storage details directly).
/// `currentUser` is backed by KeychainManager.cachedUser so a signed-in
/// session survives a full app restart (previously this was in-memory
/// only, which force-logged the owner out every time the app was closed
/// even though the tokens were still valid).
final class AppState {
    static let shared = AppState()
    private init() {
        currentUser = KeychainManager.shared.cachedUser
    }

    var currentUser: AppUser? {
        didSet { KeychainManager.shared.cachedUser = currentUser }
    }

    var isLoggedIn: Bool { KeychainManager.shared.accessToken != nil && currentUser != nil }

    /// SRS 5.1: 'Read-only users should see only permitted sections/actions.'
    var isAdmin: Bool { currentUser?.isAdmin ?? false }

    /// True for an admin-created login limited to one shopkeeper's own
    /// account (read-only: their own laptops/payments/remaining balance).
    var isShopkeeper: Bool { currentUser?.isShopkeeper ?? false }
    var ownShopkeeperId: Int? { currentUser?.shopkeeper }

    func signOut() {
        currentUser = nil
        KeychainManager.shared.clear()
    }

    /// SRS 13/17: session ended for a reason the user should be told about
    /// (inactivity timeout, or the server rejecting an expired/invalid
    /// token) -- as opposed to a normal, user-initiated "Log Out" tap.
    /// Clears local state and tells the app to bounce back to the Login
    /// screen with an explanatory alert instead of leaving stale,
    /// now-unauthorized screens on display.
    func expireSession(reason: String) {
        guard isLoggedIn else { return } // already signed out -- don't double-fire
        signOut()
        NotificationCenter.default.post(name: .sessionDidExpire, object: nil, userInfo: ["reason": reason])
    }
}

extension Notification.Name {
    static let sessionDidExpire = Notification.Name("AppState.sessionDidExpire")
}
