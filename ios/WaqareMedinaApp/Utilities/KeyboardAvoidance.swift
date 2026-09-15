import UIKit

/// Every form screen in the app puts its fields in a UIStackView inside a
/// UIScrollView, but none of them ever told that scroll view to get out of
/// the keyboard's way. `enableTapToDismissKeyboard()` (InventoryViewController.swift)
/// only lets you dismiss the keyboard by tapping elsewhere -- it doesn't stop
/// the keyboard from covering whichever field (or the Save button) happens to
/// be near the bottom of the form while it's up. On a form with more than a
/// few fields (e.g. "Add Another Laptop") this can permanently hide the field
/// currently being typed into.
///
/// Call `registerKeyboardAvoidance(for: scroll)` once from viewDidLoad, right
/// after the form's scroll view is added to the hierarchy. It shrinks the
/// scroll view's usable area by the keyboard's height and scrolls the
/// currently-focused field into view above it.
extension UIViewController {
    func registerKeyboardAvoidance(for scrollView: UIScrollView) {
        let center = NotificationCenter.default
        center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main
        ) { [weak self, weak scrollView] notification in
            self?.handleKeyboardChange(notification, scrollView: scrollView)
        }
        center.addObserver(
            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self, weak scrollView] notification in
            self?.handleKeyboardChange(notification, scrollView: scrollView)
        }
    }

    private func handleKeyboardChange(_ notification: Notification, scrollView: UIScrollView?) {
        guard let scrollView = scrollView, let hostView = viewIfLoaded,
              let keyboardEndFrameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else { return }

        let keyboardFrameInView = hostView.convert(keyboardEndFrameValue.cgRectValue, from: nil)
        let overlap = max(0, scrollView.frame.maxY - keyboardFrameInView.origin.y)

        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        UIView.animate(withDuration: duration) {
            scrollView.contentInset.bottom = overlap
            scrollView.verticalScrollIndicatorInsets.bottom = overlap
        }

        // Scroll whatever's currently focused up above the keyboard so the
        // field being typed into (and the Save button below it) are visible.
        if overlap > 0, let activeField = hostView.firstResponderView() {
            let fieldFrame = activeField.convert(activeField.bounds, to: scrollView)
            DispatchQueue.main.async {
                scrollView.scrollRectToVisible(fieldFrame.insetBy(dx: 0, dy: -16), animated: true)
            }
        }
    }
}

private extension UIView {
    func firstResponderView() -> UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let match = subview.firstResponderView() { return match }
        }
        return nil
    }
}
