import Foundation
import XCTest
import os

// MARK: - RPC Method Handler Protocol

/// Protocol for JSON-RPC method handlers.
///
/// Each handler processes a specific method and returns a result or throws an error.
@MainActor
protocol RPCMethodHandler {
    /// The method name this handler responds to.
    static var methodName: String { get }

    /// Executes the method with the given parameters.
    ///
    /// - Parameter params: The JSON parameters from the request.
    /// - Returns: The result as a JSONValue.
    /// - Throws: JSONRPCError if the method fails.
    func execute(params: JSONValue?) async throws -> JSONValue
}

// MARK: - RPC Method Error

/// Error type for RPC method execution.
enum RPCMethodError: Error {
    case invalidParams(String)
    case internalError(String)
    case timeout(String)

    var jsonRPCError: JSONRPCError {
        switch self {
        case .invalidParams(let message):
            return .invalidParams(message: message)
        case .internalError(let message):
            return .internalError(message: message)
        case .timeout(let message):
            return .timeout(message: message)
        }
    }
}
