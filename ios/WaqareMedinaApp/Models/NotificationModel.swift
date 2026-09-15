import Foundation

/// SRS 4.11, 7, 10 (Notification Requirements)
enum AppNotificationType: String, Codable {
    case lowStock = "LOW_STOCK"
    case upcomingPayment = "UPCOMING_PAYMENT"
    case paymentDue = "PAYMENT_DUE"
    case overdue = "OVERDUE"
    case sale = "SALE"
}

struct AppNotification: Codable, Equatable, Identifiable {
    let id: Int
    let type: AppNotificationType
    let title: String
    let message: String
    let scheduledAt: String?
    let sentAt: String?
    let readAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, title, message
        case scheduledAt = "scheduled_at"
        case sentAt = "sent_at"
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var isUnread: Bool { readAt == nil }
}
