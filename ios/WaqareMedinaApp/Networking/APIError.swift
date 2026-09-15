import Foundation

/// SRS 17 (Error and Exception Handling): Swift must map API errors into
/// consistent alert/banner states without exposing technical details.
enum APIError: Error, LocalizedError {
    case noConnection
    case timeout
    case unauthorized
    case invalidCredentials
    case forbidden
    case notFound
    case validation(String)
    case server(String)
    case decoding
    case unknown

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "Unable to connect to the server. Please check your internet connection."
        case .timeout:
            return "The request timed out. Please try again."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .invalidCredentials:
            return "Incorrect username or password. Please try again."
        case .forbidden:
            return "You do not have permission to perform this action."
        case .notFound:
            return "The requested record could not be found."
        case .validation(let message):
            return message
        case .server(let message):
            return message
        case .decoding:
            return "Something went wrong reading the server response. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
