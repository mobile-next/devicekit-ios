import Foundation
import FlyingFox

// MARK: - Error Types

/// Categorizes errors returned by the HTTP API.
///
/// Each error type maps to a specific HTTP status code.
///
/// | Type | HTTP Status | Description |
/// |------|-------------|-------------|
/// | `internal` | 500 | Internal server error |
/// | `precondition` | 400 | Bad request / invalid input |
/// | `timeout` | 408 | Request timeout |
enum ServerErrorType: String, Codable {

    /// Internal server error (HTTP 500).
    case `internal`

    /// Bad request or invalid parameters (HTTP 400).
    case precondition

    /// Operation timed out (HTTP 408).
    case timeout
}

// MARK: - Application Error

/// Represents an error response from the HTTP API.
///
/// This error type is serialized to JSON and returned in HTTP responses.
///
/// ## JSON Format
/// ```json
/// {
///   "code": "precondition",
///   "errorMessage": "incorrect request body provided"
/// }
/// ```
///
/// ## HTTP Status Codes
/// - `internal` → HTTP 500 Internal Server Error
/// - `precondition` → HTTP 400 Bad Request
/// - `timeout` → HTTP 408 Request Timeout
struct ServerError: Error, Codable {

    /// Error category determining the HTTP status code.
    let type: ServerErrorType

    /// Human-readable error description.
    let message: String

    /// Maps error type to HTTP status code.
    private var statusCode: HTTPStatusCode {
        switch type {
        case .internal: return .internalServerError
        case .precondition: return .badRequest
        case .timeout: return .requestTimeout
        }
    }

    /// Converts the error to an HTTP response with JSON body.
    var httpResponse: HTTPResponse {
        let body = try? JSONEncoder().encode(self)
        return HTTPResponse(statusCode: statusCode, body: body ?? Data())
    }

    /// Creates an application error.
    ///
    /// - Parameters:
    ///   - type: Error category (defaults to `.internal`).
    ///   - message: Error description.
    init(type: ServerErrorType = .internal, message: String) {
        self.type = type
        self.message = message
    }

    /// Custom JSON keys for serialization.
    private enum CodingKeys: String, CodingKey {
        case type = "code"
        case message = "errorMessage"
    }
}
