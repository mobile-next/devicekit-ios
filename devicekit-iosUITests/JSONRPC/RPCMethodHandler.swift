import Foundation
import XCTest
import os

@MainActor
protocol RPCMethodHandler {
    static var methodName: String { get }

    func execute(params: JSONValue?) async throws -> JSONValue
}

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
