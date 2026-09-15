import Foundation
import os.log

/// SRS 13 / 17: 'Log technical details safely for debugging without
/// sensitive data... Do not log access tokens, passwords or sensitive
/// personal information.'
enum AppLogger {
    private static let logger = Logger(subsystem: "com.waqaremedina.app", category: "general")

    static func error(_ message: String, error: Error? = nil) {
        if let error = error {
            logger.error("\(message, privacy: .public) — \(String(describing: error), privacy: .private)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}
