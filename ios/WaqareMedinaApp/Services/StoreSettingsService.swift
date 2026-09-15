import Foundation

/// SRS 4.13: Store name, address, phone and logo management.
final class StoreSettingsService {
    static let shared = StoreSettingsService()
    private init() {}

    func get() async throws -> StoreSettings {
        try await APIClient.shared.request(.storeSettings, method: .get)
    }

    func update(_ settings: StoreSettings) async throws -> StoreSettings {
        try await APIClient.shared.request(.storeSettings, method: .patch, body: settings)
    }
}
