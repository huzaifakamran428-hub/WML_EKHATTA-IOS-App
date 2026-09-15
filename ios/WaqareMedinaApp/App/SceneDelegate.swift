import UIKit

/// SRS 5.1 (Navigation): root UITabBarController with Dashboard,
/// Inventory, Customers, Shopkeepers, Reports; secondary flows pushed via
/// UINavigationController. Read-only users see only permitted sections.
/// A SHOPKEEPER-role login (admin-created, scoped to one shopkeeper) skips
/// the admin tab bar entirely and goes straight to their own read-only
/// account screen.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // ActivityTrackingWindow (not plain UIWindow): lets InactivityMonitor
        // see every touch in the app without each screen wiring it up itself.
        let window = ActivityTrackingWindow(windowScene: windowScene)
        if AppState.shared.isLoggedIn, let user = AppState.shared.currentUser {
            window.rootViewController = Self.makeRoot(for: user)
            InactivityMonitor.shared.start()
        } else {
            window.rootViewController = Self.makeLoginFlow()
        }
        self.window = window
        window.makeKeyAndVisible()

        // SRS 13/17: any involuntary session end (idle timeout, or the
        // server rejecting an expired/invalid token) lands here, from
        // wherever in the app it happened, and bounces back to Login with
        // a clear explanation instead of leaving dead screens on display.
        NotificationCenter.default.addObserver(
            forName: .sessionDidExpire, object: nil, queue: .main
        ) { [weak self] notification in
            self?.handleSessionExpired(reason: notification.userInfo?["reason"] as? String)
        }
    }

    private func handleSessionExpired(reason: String?) {
        InactivityMonitor.shared.stop()
        let loginFlow = Self.makeLoginFlow()
        window?.rootViewController = loginFlow
        let alert = UIAlertController(
            title: "Signed Out",
            message: reason ?? "Your session has expired. Please log in again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        loginFlow.present(alert, animated: true)
    }

    static func makeLoginFlow() -> UIViewController {
        UINavigationController(rootViewController: LoginViewController())
    }

    /// Picks the right root for the signed-in user's role.
    static func makeRoot(for user: AppUser) -> UIViewController {
        if user.isShopkeeper, let shopkeeperId = user.shopkeeper {
            return makeShopkeeperOwnAccountRoot(shopkeeperId: shopkeeperId)
        }
        return makeMainTabBar()
    }

    /// A shopkeeper's own login: one screen, their own account, read-only.
    /// No tabs, no other shopkeepers' data reachable.
    static func makeShopkeeperOwnAccountRoot(shopkeeperId: Int) -> UIViewController {
        let detail = ShopkeeperDetailViewController(shopkeeperId: shopkeeperId)
        detail.title = "My Account"
        detail.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Log Out", style: .plain, target: detail, action: #selector(ShopkeeperDetailViewController.logOutTapped)
        )
        return UINavigationController(rootViewController: detail)
    }

    static func makeMainTabBar() -> UITabBarController {
        let tabBar = UITabBarController()
        let isAdmin = AppState.shared.isAdmin

        let dashboard = wrap(DashboardViewController(), title: "Dashboard", icon: "house.fill")
        let inventory = wrap(InventoryViewController(), title: "Inventory", icon: "laptopcomputer")
        let customers = wrap(CustomersViewController(), title: "Customers", icon: "person.2.fill")
        let shopkeepers = wrap(ShopkeepersViewController(), title: "Shopkeepers", icon: "storefront.fill")
        let reports = wrap(ReportsViewController(), title: "Reports", icon: "chart.bar.fill")
        // SettingsViewController is the only place Log Out lives, so every
        // signed-in role needs a way to reach it -- not just admins.
        // SettingsViewController itself hides the admin-only rows (Manage
        // Users, Audit Log) for non-admins, so Read-Only still can't reach
        // anything beyond what SRS 2 permits; it just keeps Store Profile,
        // Receipt Search and Log Out.
        let settings = wrap(SettingsViewController(), title: "Settings", icon: "gearshape.fill")

        var tabs = [dashboard, inventory, customers, shopkeepers]
        if isAdmin {
            tabs.append(reports) // SRS 2: Read-Only cannot view/export beyond permitted records
        }
        tabs.append(settings)
        tabBar.viewControllers = tabs
        return tabBar
    }

    private static func wrap(_ vc: UIViewController, title: String, icon: String) -> UINavigationController {
        vc.title = title
        vc.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), tag: 0)
        return UINavigationController(rootViewController: vc)
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
