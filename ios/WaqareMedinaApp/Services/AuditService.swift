import Foundation

/// SRS 4.13: Audit record viewing for important changes.
final class AuditService {
    static let shared = AuditService()
    private init() {}

    struct ListResponse: Decodable { let results: [AuditLogEntry]; let count: Int }

    func list() async throws -> [AuditLogEntry] {
        let response: ListResponse = try await APIClient.shared.request(.auditLogs, method: .get)
        return response.results
    }
}
