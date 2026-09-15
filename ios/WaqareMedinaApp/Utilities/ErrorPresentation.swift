import UIKit

/// SRS 17 (Error and Exception Handling): "If something goes wrong, show a
/// clear error message instead of crashing or silently failing." Every
/// screen's Task { do { ... } catch { ... } } network call routes its
/// failure through here, so the behavior (and wording) stays consistent
/// app-wide instead of each screen inventing its own alert.
extension UIViewController {
    func presentErrorAlert(_ error: Error) {
        // .unauthorized means the session already ended and
        // AuthService/InactivityMonitor has already (or is about to)
        // post .sessionDidExpire, which bounces the whole app back to
        // Login with its own explanatory alert. Showing a second, vaguer
        // "Something went wrong" here on top of that -- possibly on a
        // screen that's no longer even on screen by the time it appears
        // -- would just be confusing, so this one specific case is a
        // deliberate no-op.
        if case APIError.unauthorized = error { return }

        let alert = UIAlertController(title: "Something went wrong", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
