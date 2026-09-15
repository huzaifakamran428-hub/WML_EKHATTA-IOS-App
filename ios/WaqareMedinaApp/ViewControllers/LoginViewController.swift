import UIKit

/// Screen 1 — SRS 4.1, 5, 13: Email/password authentication; Keychain-
/// backed session; clear error messages. Social sign-in buttons removed
/// per owner request; fields enlarged/modernized (Theme.styleLargeField).
final class LoginViewController: UIViewController {
    private let usernameField = FormTextField(label: "Username or Email")
    private let passwordField = FormTextField(label: "Password")
    private let loginButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    #if DEBUG
    private let serverButton = UIButton(type: .system)
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "WML EKhatta"
        enableTapToDismissKeyboard()
        passwordField.enableSecureEntryToggle()

        let logoView = UIImageView(image: UIImage(named: "Logo"))
        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.heightAnchor.constraint(equalToConstant: 110).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "WML EKhatta"
        titleLabel.font = .boldSystemFont(ofSize: 30)
        titleLabel.textColor = Theme.brand
        titleLabel.textAlignment = .center
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Computers and Laptop"
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        Theme.styleLargeField(usernameField.textField)
        Theme.styleLargeField(passwordField.textField)

        Theme.stylePrimaryButton(loginButton, title: "Log In")
        loginButton.addTarget(self, action: #selector(handleLogin), for: .touchUpInside)

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.isHidden = true

        var fields: [UIView] = [
            logoView, titleLabel, subtitleLabel, usernameField, passwordField,
            errorLabel, loginButton, activityIndicator,
        ]
        #if DEBUG
        // Debug-only escape hatch: 127.0.0.1 only works in the Simulator.
        // A physical device needs the Mac's actual LAN IP, which changes
        // between networks — this lets that be set from the phone itself
        // instead of requiring an Xcode edit + rebuild every time.
        updateServerButtonTitle()
        serverButton.titleLabel?.font = .systemFont(ofSize: 12)
        serverButton.setTitleColor(.tertiaryLabel, for: .normal)
        serverButton.addTarget(self, action: #selector(showServerAddressPrompt), for: .touchUpInside)
        fields.append(serverButton)
        #endif

        let stack = UIStackView(arrangedSubviews: fields)
        stack.axis = .vertical
        stack.spacing = 18
        stack.setCustomSpacing(16, after: logoView)
        stack.setCustomSpacing(4, after: titleLabel)
        stack.setCustomSpacing(36, after: subtitleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Previously this stack was pinned straight to the view with a
        // centerYAnchor constraint and no keyboard handling at all. On
        // shorter screens (or with the debug server row visible) tapping
        // the password field let the keyboard slide up over it -- there
        // was nothing to shrink the usable area or scroll the field back
        // into view. Wrapping the form in a UIScrollView and registering
        // the same keyboard-avoidance helper the other forms use fixes
        // that: the scroll view's bottom inset grows by the keyboard's
        // height and the focused field is scrolled back above it.
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        view.addSubview(scroll)
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(greaterThanOrEqualTo: scroll.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: scroll.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -56),
        ])
        // Keeps the form vertically centered like before when there's
        // room, while still letting it scroll instead of fighting the
        // top/bottom anchors above if the keyboard (or a small screen)
        // doesn't leave enough space.
        let centerY = stack.centerYAnchor.constraint(equalTo: scroll.centerYAnchor)
        centerY.priority = .defaultLow
        centerY.isActive = true
        registerKeyboardAvoidance(for: scroll)
    }

    @objc private func handleLogin() {
        errorLabel.isHidden = true
        activityIndicator.startAnimating()
        loginButton.isEnabled = false
        Task {
            do {
                let username = try Validator.requireNonEmpty(usernameField.text, fieldName: "username")
                let password = try Validator.requireNonEmpty(passwordField.text, fieldName: "password")
                let user = try await AuthService.shared.login(username: username, password: password)
                await MainActor.run { self.goToMainApp(for: user) }
            } catch {
                await MainActor.run { self.showError(error) }
            }
            await MainActor.run {
                self.activityIndicator.stopAnimating()
                self.loginButton.isEnabled = true
            }
        }
    }

    private func goToMainApp(for user: AppUser) {
        guard let windowScene = view.window?.windowScene, let sceneDelegate = windowScene.delegate as? SceneDelegate else { return }
        sceneDelegate.window?.rootViewController = SceneDelegate.makeRoot(for: user)
        InactivityMonitor.shared.start()
    }

    private func showError(_ error: Error) {
        errorLabel.text = error.localizedDescription
        errorLabel.isHidden = false
    }

    #if DEBUG
    private func updateServerButtonTitle() {
        let current = APIConfig.debugServerOverride
        let display = (current?.isEmpty ?? true) ? "127.0.0.1:8000 (Simulator default)" : current!
        serverButton.setTitle("Server: \(display)  (tap to change)", for: .normal)
    }

    @objc private func showServerAddressPrompt() {
        let alert = UIAlertController(
            title: "Server Address",
            message: "For a physical device, this needs to be your Mac's LAN IP (not 127.0.0.1 — a real phone can't reach the Mac's own loopback address). You can just type the bare IP, e.g. 192.168.1.5 — http://, the :8000 port, and /api/ will be filled in automatically if you leave them out. Leave blank to use the Simulator default.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "http://192.168.1.5:8000/api/"
            field.text = APIConfig.debugServerOverride
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            APIConfig.setDebugServerOverride(alert?.textFields?.first?.text)
            self?.updateServerButtonTitle()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    #endif
}
