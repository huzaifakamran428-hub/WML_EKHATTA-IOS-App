import UIKit
import UserNotifications

/// SRS 3.1 (Build/Deployment), 4.11 (UserNotifications + APNs)
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        registerForPushNotifications(application)
        return true
    }

    private func registerForPushNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // SRS 4.11: 'Notification failures must not crash the app.'
            guard granted, error == nil else {
                AppLogger.info("Push notification permission not granted.")
                return
            }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            do {
                try await NotificationService.shared.registerDeviceToken(tokenString)
            } catch {
                // SRS 4.11: notification failures must not crash the app.
                AppLogger.error("Failed to register device token", error: error)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppLogger.error("Remote notification registration failed", error: error)
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
