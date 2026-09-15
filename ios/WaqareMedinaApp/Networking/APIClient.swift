import Foundation

/// SRS 3.1 (Networking: URLSession, JSON: Codable), 3.3 ('Network/API
/// service classes should isolate URLSession/API communication from
/// ViewControllers'), 17 (Error and Exception Handling), 13 (Security:
/// HTTPS, secure token handling).
///
/// A single, small, dependency-free API client used by every Services/*
/// class. Handles JSON encode/decode, auth headers, 401 refresh-and-retry,
/// and maps transport/HTTP failures onto APIError so ViewControllers only
/// ever see typed, user-safe errors (SRS 17).
final class APIClient {
    static let shared = APIClient()
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    enum Method: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

    /// Generic typed request. `retrying` guards against infinite refresh loops.
    func request<Body: Encodable, Response: Decodable>(
        _ endpoint: APIEndpoint,
        method: Method,
        body: Body? = nil,
        authorized: Bool = true,
        retrying: Bool = false
    ) async throws -> Response {
        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authorized, let token = KeychainManager.shared.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            urlRequest.httpBody = try? encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dnsLookupFailed, .resourceUnavailable:
                // On a physical device, "cannotConnectToHost" is almost
                // always APIConfig.baseURL pointing at 127.0.0.1 (which
                // only resolves back to the device itself, not the Mac
                // running the backend) — surfaced with the same clear
                // message as being fully offline, since to the user it's
                // the same problem: the server can't be reached.
                throw APIError.noConnection
            case .timedOut: throw APIError.timeout
            default: throw APIError.unknown
            }
        } catch {
            throw APIError.unknown
        }

        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.unknown }

        switch httpResponse.statusCode {
        case 200...299:
            if Response.self == EmptyResponse.self {
                return EmptyResponse() as! Response
            }
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding
            }
        case 401:
            // SRS 4.1: 'Handle token expiry/refresh and session expiration
            // without crashing.'
            //
            // Important distinction: a 401 on an *unauthorized* request
            // (login, Google/Apple login, token refresh — none of which
            // send a Bearer token) means the credentials themselves were
            // rejected, not that a session expired. Only a 401 on an
            // *authorized* (token-bearing) request represents an actual
            // expired/invalid session worth attempting a refresh for.
            guard authorized else {
                throw APIError.invalidCredentials
            }
            if !retrying, await AuthService.shared.refreshTokenIfPossible() {
                return try await request(endpoint, method: method, body: body, authorized: authorized, retrying: true)
            }
            // Every caller's presentErrorAlert(_:) deliberately no-ops on
            // .unauthorized, on the assumption that a "Signed Out" alert +
            // redirect-to-Login has already happened via
            // AuthService.refreshTokenIfPossible()'s own failure branch.
            // That's only true when the *refresh* attempt itself failed.
            // If the refresh succeeded but this retried, now-authorized
            // request STILL got a 401 (e.g. the account is momentarily
            // rejected for a reason unrelated to the access token itself),
            // that branch never ran and nothing would ever tell the app to
            // go back to Login -- every screen would just go silently
            // blank instead. Firing the same expireSession/.sessionDidExpire
            // path here too guarantees a 401 that survives a retry always
            // ends in a clear "please log in again", never a stuck screen.
            AppState.shared.expireSession(reason: "Your session has expired. Please log in again.")
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 400, 422:
            let message = (try? decoder.decode(APIValidationError.self, from: data))?.readableMessage
            throw APIError.validation(message ?? "Please check the entered information and try again.")
        case 500...599:
            throw APIError.server("The server ran into a problem. Please try again.")
        default:
            throw APIError.unknown
        }
    }

    func request<Response: Decodable>(_ endpoint: APIEndpoint, method: Method, authorized: Bool = true) async throws -> Response {
        try await request(endpoint, method: method, body: Optional<EmptyBody>.none, authorized: authorized)
    }
}

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}

/// Maps DRF's default error shapes ({"detail": "..."} or field errors)
/// into one readable string (SRS 17: 'clear user-facing messages').
struct APIValidationError: Decodable {
    let detail: String?
    private let fieldErrors: [String: [String]]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        if let detailKey = DynamicKey(stringValue: "detail"), let value = try? container.decode(String.self, forKey: detailKey) {
            self.detail = value
            self.fieldErrors = nil
        } else {
            self.detail = nil
            var errors: [String: [String]] = [:]
            for key in container.allKeys {
                if let values = try? container.decode([String].self, forKey: key) {
                    errors[key.stringValue] = values
                } else if let value = try? container.decode(String.self, forKey: key) {
                    errors[key.stringValue] = [value]
                }
            }
            self.fieldErrors = errors
        }
    }

    var readableMessage: String {
        if let detail = detail { return detail }
        if let fieldErrors = fieldErrors, !fieldErrors.isEmpty {
            return fieldErrors.values.flatMap { $0 }.joined(separator: "\n")
        }
        return "Please check the entered information and try again."
    }
}

private struct DynamicKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
}
