import Foundation

// MARK: - JSON-RPC 2.0 Protocol Models

/// JSON-RPC 2.0 request identifier.
///
/// Supports both string and integer identifiers as per the JSON-RPC specification.
enum JSONRPCId: Codable, Equatable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                JSONRPCId.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or Int for JSON-RPC id"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        }
    }
}

// MARK: - JSON-RPC Request

/// JSON-RPC 2.0 request object.
///
/// ## JSON Format
/// ```json
/// {
///   "jsonrpc": "2.0",
///   "method": "tap",
///   "params": {"x": 100.0, "y": 200.0},
///   "id": 1
/// }
/// ```
struct JSONRPCRequest: Codable {
    /// Protocol version (must be "2.0").
    let jsonrpc: String

    /// Method name to invoke.
    let method: String

    /// Method parameters (optional).
    let params: JSONValue?

    /// Request identifier (optional for notifications).
    let id: JSONRPCId?

    /// Validates that the request conforms to JSON-RPC 2.0.
    var isValid: Bool {
        jsonrpc == "2.0"
    }
}

// MARK: - JSON-RPC Response

/// JSON-RPC 2.0 response object.
///
/// ## Success Response
/// ```json
/// {
///   "jsonrpc": "2.0",
///   "result": {"success": true},
///   "id": 1
/// }
/// ```
///
/// ## Error Response
/// ```json
/// {
///   "jsonrpc": "2.0",
///   "error": {"code": -32601, "message": "Method not found"},
///   "id": 1
/// }
/// ```
struct JSONRPCResponse: Codable {
    /// Protocol version (always "2.0").
    let jsonrpc: String = "2.0"

    /// Result on success (mutually exclusive with error).
    let result: JSONValue?

    /// Error on failure (mutually exclusive with result).
    let error: JSONRPCError?

    /// Request identifier (null for notifications).
    let id: JSONRPCId?

    /// Creates a success response.
    static func success(result: JSONValue?, id: JSONRPCId?) -> JSONRPCResponse {
        JSONRPCResponse(result: result, error: nil, id: id)
    }

    /// Creates an error response.
    static func failure(error: JSONRPCError, id: JSONRPCId?) -> JSONRPCResponse {
        JSONRPCResponse(result: nil, error: error, id: id)
    }
}

// MARK: - JSON-RPC Error

/// JSON-RPC 2.0 error object.
///
/// ## Standard Error Codes
/// | Code | Message | Description |
/// |------|---------|-------------|
/// | -32700 | Parse error | Invalid JSON |
/// | -32600 | Invalid Request | Not a valid request object |
/// | -32601 | Method not found | Method does not exist |
/// | -32602 | Invalid params | Invalid method parameters |
/// | -32603 | Internal error | Internal JSON-RPC error |
struct JSONRPCError: Codable {
    /// Error code.
    let code: Int

    /// Short error description.
    let message: String

    /// Additional error data (optional).
    let data: JSONValue?

    init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // Standard JSON-RPC 2.0 error codes
    static let parseError = JSONRPCError(code: -32700, message: "Parse error")
    static let invalidRequest = JSONRPCError(code: -32600, message: "Invalid Request")
    static let methodNotFound = JSONRPCError(code: -32601, message: "Method not found")
    static let invalidParams = JSONRPCError(code: -32602, message: "Invalid params")
    static let internalError = JSONRPCError(code: -32603, message: "Internal error")

    /// Creates an internal error with custom message.
    static func internalError(message: String) -> JSONRPCError {
        JSONRPCError(code: -32603, message: message)
    }

    /// Creates an invalid params error with custom message.
    static func invalidParams(message: String) -> JSONRPCError {
        JSONRPCError(code: -32602, message: message)
    }

    /// Server error for timeout (application-defined).
    static func timeout(message: String) -> JSONRPCError {
        JSONRPCError(code: -32000, message: message)
    }

    /// Server error for precondition failure (application-defined).
    static func preconditionFailed(message: String) -> JSONRPCError {
        JSONRPCError(code: -32001, message: message)
    }
}

// MARK: - JSON Value (Dynamic Type)

/// A type-erased JSON value for handling dynamic parameters and results.
///
/// Supports all JSON types: null, bool, int, double, string, array, object.
enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode JSON value"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    /// Converts the JSON value to Data for decoding into specific types.
    func toData() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Creates a JSONValue from any Encodable type.
    static func from<T: Encodable>(_ value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

// MARK: - Convenience Extensions

extension JSONValue {
    /// Subscript for accessing object values.
    subscript(key: String) -> JSONValue? {
        guard case .object(let dict) = self else { return nil }
        return dict[key]
    }

    /// Subscript for accessing array values.
    subscript(index: Int) -> JSONValue? {
        guard case .array(let array) = self, index < array.count else { return nil }
        return array[index]
    }
}
