import UIKit

/// SRS 13 ("session should expire after a period of inactivity").
///
/// The backend already enforces this per-request
/// (InactivityAwareJWTAuthentication), but that only fires the *next time
/// the app happens to call the API*. If the user leaves the app sitting
/// open on a screen that makes no further requests, nothing would ever
/// notice they've gone idle. This is the client-side half: it watches for
/// touches anywhere in the app (via ActivityTrackingWindow) and for time
/// spent backgrounded, and signs the user out locally the moment either
/// exceeds the timeout -- without waiting on a network call.
final class InactivityMonitor {
    static let shared = InactivityMonitor()
    private init() {}

    /// Kept in sync with the backend's SESSION_INACTIVITY_TIMEOUT_MINUTES
    /// default; only used for the local, client-side check, so a mismatch
    /// isn't dangerous either way -- whichever side notices first wins.
    var timeoutInterval: TimeInterval = 30 * 60

    private var lastActivityAt = Date()
    private var checkTimer: Timer?
    private var backgroundedAt: Date?

    func start() {
        lastActivityAt = Date()
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkTimedOut()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground),
                                                name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
                                                name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
        backgroundedAt = nil
        NotificationCenter.default.removeObserver(self)
    }

    /// Called on every touch via ActivityTrackingWindow.sendEvent.
    func recordActivity() {
        lastActivityAt = Date()
    }

    private func checkTimedOut() {
        guard AppState.shared.isLoggedIn else { return }
        if Date().timeIntervalSince(lastActivityAt) > timeoutInterval {
            AppState.shared.expireSession(reason: "You were signed out after a period of inactivity.")
        }
    }

    @objc private func appDidEnterBackground() {
        backgroundedAt = Date()
    }

    /// A suspended app doesn't get Timer callbacks, so time spent
    /// backgrounded has to be checked in one shot on return instead of
    /// relying on the periodic timer to have "caught up".
    @objc private func appWillEnterForeground() {
        defer { backgroundedAt = nil }
        guard let backgroundedAt, AppState.shared.isLoggedIn else { return }
        if Date().timeIntervalSince(backgroundedAt) > timeoutInterval {
            AppState.shared.expireSession(reason: "You were signed out after a period of inactivity.")
        } else {
            recordActivity()
        }
    }
}

/// Routes every touch in the app through InactivityMonitor without every
/// individual ViewController needing to know or care about it.
final class ActivityTrackingWindow: UIWindow {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
        if event.type == .touches {
            InactivityMonitor.shared.recordActivity()
        }
    }
}
