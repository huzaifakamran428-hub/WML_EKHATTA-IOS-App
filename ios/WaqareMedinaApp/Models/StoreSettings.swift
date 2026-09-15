import Foundation

/// SRS 4.13, 5 (StoreProfileViewController), 15 (Professional Bill Spec)
struct StoreSettings: Codable, Equatable {
    var storeName: String
    var address: String
    var phoneNumber: String
    var logoURL: String?
    // Owner request: CEO name + contact number, printed on every bill
    // alongside the store name/address/phone (see PDFBuilder.drawHeader).
    var ceoName: String
    var ceoContactNumber: String
    var thankYouMessage: String
    var lowStockAlertsEnabled: Bool
    var dueTodayReminderEnabled: Bool
    var twoDayReminderEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case address
        case storeName = "store_name"
        case phoneNumber = "phone_number"
        case logoURL = "logo"
        case ceoName = "ceo_name"
        case ceoContactNumber = "ceo_contact_number"
        case thankYouMessage = "thank_you_message"
        case lowStockAlertsEnabled = "low_stock_alerts_enabled"
        case dueTodayReminderEnabled = "due_today_reminder_enabled"
        case twoDayReminderEnabled = "two_day_reminder_enabled"
    }
}
