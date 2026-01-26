import Foundation
import os

// MARK: - JSON-RPC Dispatcher

/// Routes JSON-RPC requests to the appropriate method handlers.
///
/// The dispatcher maintains a registry of method handlers and processes
/// incoming requests by looking up and invoking the corresponding handler.
///
/// ## Supported Methods
/// - `tap`: Performs tap/long-press gestures
/// - `dump_ui`: Captures UI view hierarchy
///
/// ## Usage
/// ```swift
/// let dispatcher = JSONRPCDispatcher()
/// let response = await dispatcher.dispatch(requestData)
/// ```
@MainActor
final class JSONRPCDispatcher {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "JSONRPCDispatcher"
    )

    /// Registered method handlers keyed by method name.
    private var handlers: [String: any RPCMethodHandler] = [:]

    /// Initializes the dispatcher with default method handlers.
    init() {
        registerHandler(TapMethodHandler())
        registerHandler(DumpUIMethodHandler())
    }

    /// Registers a method handler.
    ///
    /// - Parameter handler: The handler to register.
    func registerHandler<T: RPCMethodHandler>(_ handler: T) {
        handlers[T.methodName] = handler
    }

    /// Dispatches a JSON-RPC request and returns the response.
    ///
    /// - Parameter data: Raw JSON data containing the request.
    /// - Returns: JSON-encoded response data.
    func dispatch(_ data: Data) async -> Data {
        let response = await processRequest(data)
        return encodeResponse(response)
    }

    /// Dispatches a JSON-RPC request string and returns the response string.
    ///
    /// - Parameter message: JSON string containing the request.
    /// - Returns: JSON string containing the response.
    func dispatch(_ message: String) async -> String {
        guard let data = message.data(using: .utf8) else {
            let response = JSONRPCResponse.failure(error: .parseError, id: nil)
            return String(data: encodeResponse(response), encoding: .utf8) ?? "{}"
        }
        let responseData = await dispatch(data)
        return String(data: responseData, encoding: .utf8) ?? "{}"
    }

    // MARK: - Private Methods

    private func processRequest(_ data: Data) async -> JSONRPCResponse {
        let request: JSONRPCRequest
        do {
            request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
        } catch {
            logger.error("Failed to parse JSON-RPC request: \(error.localizedDescription)")
            return JSONRPCResponse.failure(error: .parseError, id: nil)
        }

        guard request.isValid else {
            logger.error("Invalid JSON-RPC request: jsonrpc must be '2.0'")
            return JSONRPCResponse.failure(error: .invalidRequest, id: request.id)
        }

        guard let handler = handlers[request.method] else {
            logger.error("Method not found: \(request.method)")
            return JSONRPCResponse.failure(error: .methodNotFound, id: request.id)
        }

        do {
            logger.info("Executing method: \(request.method)")
            let result = try await handler.execute(params: request.params)
            logger.info("Method \(request.method) completed successfully")
            return JSONRPCResponse.success(result: result, id: request.id)
        } catch let error as RPCMethodError {
            logger.error("Method \(request.method) failed: \(error.jsonRPCError.message)")
            return JSONRPCResponse.failure(error: error.jsonRPCError, id: request.id)
        } catch {
            logger.error("Method \(request.method) failed with unexpected error: \(error.localizedDescription)")
            return JSONRPCResponse.failure(
                error: .internalError(message: error.localizedDescription),
                id: request.id
            )
        }
    }

    private func encodeResponse(_ response: JSONRPCResponse) -> Data {
        do {
            return try JSONEncoder().encode(response)
        } catch {
            logger.error("Failed to encode response: \(error.localizedDescription)")
            let fallback = """
            {"jsonrpc":"2.0","error":{"code":-32603,"message":"Failed to encode response"},"id":null}
            """
            return fallback.data(using: .utf8) ?? Data()
        }
    }
}

// MARK: - Batch Request Support

extension JSONRPCDispatcher {
    /// Dispatches a batch of JSON-RPC requests.
    ///
    /// - Parameter data: Raw JSON data containing an array of requests.
    /// - Returns: JSON-encoded array of responses.
    func dispatchBatch(_ data: Data) async -> Data {
        guard let requests = try? JSONDecoder().decode([JSONRPCRequest].self, from: data) else {
            let response = JSONRPCResponse.failure(error: .invalidRequest, id: nil)
            return encodeResponse(response)
        }

        var responses: [JSONRPCResponse] = []
        for request in requests {
            let requestData: Data
            do {
                requestData = try JSONEncoder().encode(request)
            } catch {
                responses.append(JSONRPCResponse.failure(error: .internalError, id: request.id))
                continue
            }
            let response = await processRequest(requestData)
            // Only include response if request had an id (not a notification)
            if request.id != nil {
                responses.append(response)
            }
        }

        do {
            return try JSONEncoder().encode(responses)
        } catch {
            let fallback = "[]"
            return fallback.data(using: .utf8) ?? Data()
        }
    }
}
