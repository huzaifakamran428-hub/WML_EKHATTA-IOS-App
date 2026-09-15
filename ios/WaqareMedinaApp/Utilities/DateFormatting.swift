import Foundation

/// Shared date parsing/formatting for API (ISO 8601 date / date-time)
/// and display (SRS 4.6, 4.11 examples like '10 October').
enum AppDateFormat {
    static let apiDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Karachi")
        return f
    }()

    static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    static func displayString(fromAPIDate apiDate: String) -> String {
        guard let date = self.apiDate.date(from: String(apiDate.prefix(10))) else { return apiDate }
        return display.string(from: date)
    }
}
