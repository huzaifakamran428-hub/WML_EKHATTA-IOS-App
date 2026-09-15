import Foundation

/// Central API configuration for the Waqare Medina app.
enum APIConfig {

    private static let overrideDefaultsKey =
        "com.waqaremedina.debugServerURLOverride"

    /// Production Render API.
    private static let builtInBaseURL =
        "https://wmlbackend.onrender.com/api/"

    /// Base URL used by the application.
    ///
    /// In DEBUG mode, a manually configured server address may be used.
    /// Otherwise, the production Render URL is used.
    static var baseURL: URL {

        #if DEBUG
        if let saved = UserDefaults.standard.string(
            forKey: overrideDefaultsKey
        ),
        !saved.isEmpty,
        let url = URL(string: saved) {
            return url
        }
        #endif

        return URL(string: builtInBaseURL)!
    }

    #if DEBUG

    /// Current manually configured debug server.
    static var debugServerOverride: String? {
        UserDefaults.standard.string(forKey: overrideDefaultsKey)
    }

    /// Configure a debug server address.
    ///
    /// Examples:
    ///
    /// Local Mac:
    /// http://192.168.1.5:8000
    ///
    /// Production:
    /// https://wmlbackend.onrender.com
    static func setDebugServerOverride(_ raw: String?) {

        guard var value = raw?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {

            UserDefaults.standard.removeObject(
                forKey: overrideDefaultsKey
            )

            return
        }

        // Add scheme if the user entered only a hostname/IP.
        if !value.contains("://") {
            value = "http://" + value
        }

        guard var components = URLComponents(string: value),
              let scheme = components.scheme,
              let host = components.host else {

            UserDefaults.standard.removeObject(
                forKey: overrideDefaultsKey
            )

            return
        }

        // Only add port 8000 for HTTP local development.
        //
        // DO NOT add :8000 to HTTPS/Render.
        if components.port == nil,
           scheme.lowercased() == "http" {

            components.port = 8000
        }

        // Always use /api/ as the API root.
        components.path = "/api/"

        // Remove query and fragment from server address.
        components.query = nil
        components.fragment = nil

        guard let finalURL = components.url else {
            UserDefaults.standard.removeObject(
                forKey: overrideDefaultsKey
            )

            return
        }

        UserDefaults.standard.set(
            finalURL.absoluteString,
            forKey: overrideDefaultsKey
        )

        print("DEBUG API Server: \(finalURL.absoluteString)")
    }

    /// Completely remove any manually configured server address.
    static func clearDebugServerOverride() {

        UserDefaults.standard.removeObject(
            forKey: overrideDefaultsKey
        )

        print("DEBUG API Server override cleared.")
        print("DEBUG API Server now: \(builtInBaseURL)")
    }

    #endif
}


enum APIEndpoint {

    case login
    case googleLogin
    case appleLogin
    case logout
    case tokenRefresh

    case users
    case user(Int)

    case laptops
    case laptop(Int)

    case customers
    case customer(Int)

    case shopkeepers
    case shopkeeper(Int)
    case shopkeeperLaptops
    case shopkeeperLaptop(Int)
    case shopkeeperExtraMoneyList
    case shopkeeperExtraMoney(Int)
    case shopkeeperPayments
    case shopkeeperPayment(Int)

    case sales
    case sale(Int)
    case receiptSearch(String)

    case creditPlans
    case creditPlan(Int)

    case payments

    case notifications
    case notificationRead(Int)

    case deviceTokens

    case reportSales
    case reportProfit
    case reportInventory
    case reportInvestment
    case reportOutstanding
    case reportPayments

    case storeSettings
    case auditLogs

    var path: String {

        switch self {

        case .login:
            return "auth/login/"

        case .googleLogin:
            return "auth/google/"

        case .appleLogin:
            return "auth/apple/"

        case .logout:
            return "auth/logout/"

        case .tokenRefresh:
            return "auth/token/refresh/"

        case .users:
            return "users/"

        case .user(let id):
            return "users/\(id)/"

        case .laptops:
            return "laptops/"

        case .laptop(let id):
            return "laptops/\(id)/"

        case .customers:
            return "customers/"

        case .customer(let id):
            return "customers/\(id)/"

        case .shopkeepers:
            return "shopkeepers/"

        case .shopkeeper(let id):
            return "shopkeepers/\(id)/"

        case .shopkeeperLaptops:
            return "shopkeeper-laptops/"

        case .shopkeeperLaptop(let id):
            return "shopkeeper-laptops/\(id)/"

        case .shopkeeperExtraMoneyList:
            return "shopkeeper-extra-money/"

        case .shopkeeperExtraMoney(let id):
            return "shopkeeper-extra-money/\(id)/"

        case .shopkeeperPayments:
            return "shopkeeper-payments/"

        case .shopkeeperPayment(let id):
            return "shopkeeper-payments/\(id)/"

        case .sales:
            return "sales/"

        case .sale(let id):
            return "sales/\(id)/"

        case .receiptSearch(let receiptNo):
            return "sales/receipt/\(receiptNo)/"

        case .creditPlans:
            return "credit-plans/"

        case .creditPlan(let id):
            return "credit-plans/\(id)/"

        case .payments:
            return "payments/"

        case .notifications:
            return "notifications/"

        case .notificationRead(let id):
            return "notifications/\(id)/read/"

        case .deviceTokens:
            return "device-tokens/"

        case .reportSales:
            return "reports/sales/"

        case .reportProfit:
            return "reports/profit/"

        case .reportInventory:
            return "reports/inventory/"

        case .reportInvestment:
            return "reports/investment/"

        case .reportOutstanding:
            return "reports/outstanding/"

        case .reportPayments:
            return "reports/payments/"

        case .storeSettings:
            return "store-settings/"

        case .auditLogs:
            return "audit-logs/"
        }
    }

    var url: URL {
        APIConfig.baseURL.appendingPathComponent(path)
    }
} 
