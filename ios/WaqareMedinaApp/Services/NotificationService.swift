import Foundation

/// SRS 4.11 (Installment Notifications), 4.2 (Dashboard alerts)
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    struct ListResponse: Decodable { let results: [AppNotification]; let count: Int }

    func list() async throws -> [AppNotification] {
        let response: ListResponse = try await APIClient.shared.request(.notifications, method: .get)
        return response.results
    }

    func markRead(id: Int) async throws {
        _ = try await APIClient.shared.request(.notificationRead(id), method: .patch, body: EmptyBody()) as EmptyResponse
    }

    /// SRS 4.11: 'Swift registers for APNs permission and device token;
    /// backend stores device tokens.'
    func registerDeviceToken(_ token: String) async throws {
        struct Body: Encodable { let token: String; let platform: String }
        _ = try await APIClient.shared.request(.deviceTokens, method: .post, body: Body(token: token, platform: "ios")) as EmptyResponse
    }
}
