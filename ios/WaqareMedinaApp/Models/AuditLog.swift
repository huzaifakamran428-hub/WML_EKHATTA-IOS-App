import Foundation

/// SRS 4.13, 7, 11, 18 (Auditability)
struct AuditLogEntry: Codable, Equatable, Identifiable {
    let id: Int
    let userDisplay: String
    let action: String
    let entity: String
    let entityId: String
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case id, action, entity, timestamp
        case userDisplay = "user_display"
        case entityId = "entity_id"
    }
}
