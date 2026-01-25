import os

/// Configuration constants for swipe gesture behavior.
private enum Constants {
    /// Default duration (in seconds) for a synthesized swipe gesture.
    /// A short delay helps avoid dropped events when interacting with
    /// system-level gesture recognizers.
    static let defaultSwipeDuration = 0.1
}

/// A JSON‑RPC request describing a swipe gesture to perform on an iOS device.
///
/// The request contains the device identifier and the start/end coordinates
/// of the swipe in screen space.
struct IOSwipeRequest: Decodable {
    /// The target device identifier.
    let deviceId: String

    /// Starting X coordinate of the swipe.
    let x1: Int

    /// Starting Y coordinate of the swipe.
    let y1: Int

    /// Ending X coordinate of the swipe.
    let x2: Int

    /// Ending Y coordinate of the swipe.
    let y2: Int
}

/// JSON‑RPC method handler for performing swipe gestures on an iOS device.
///
/// This handler decodes the incoming parameters, constructs a synthesized
/// swipe event using private XCTest SPI, and forwards it to the
/// `RunnerDaemonProxy` for execution.
///
/* Example usage with `curl`
 curl -X POST http://127.0.0.1:12004/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "io_swipe",
    "params": {
      "deviceId": "dd",
      "x1": 0,
      "y1": 0,
      "x2": 0,
      "y2": 700
    },
    "id": 42
  }'
 */
///
/* Example usage with ws
 {"jsonrpc": "2.0", "method": "io_swipe", "params": { "deviceId": "dd", "x1": 0, "y1": 0, "x2": 0, "y2": 700 }, "id": 42 }
 */
///
@MainActor
struct IOSwipeMethodHandler: RPCMethodHandler {

    /// The JSON‑RPC method name exposed by this handler.
    static let methodName = "io_swipe"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Executes the `io_swipe` JSON‑RPC method.
    ///
    /// - Parameter params: The JSON‑RPC parameters containing swipe coordinates.
    /// - Returns: A JSON object `{ "success": true }` on success.
    /// - Throws: `RPCMethodError` if decoding fails or the gesture cannot be synthesized.
    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for io_swipe method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: IOSwipeRequest
        do {
            request = try JSONDecoder().decode(IOSwipeRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid io_swipe parameters: \(error.localizedDescription)")
        }

        do {
            try await swipePrivateAPI(
                start: CGPoint(x: request.x1, y: request.y1),
                end: CGPoint(x: request.x2, y: request.y2),
                duration: Constants.defaultSwipeDuration
            )

            return .object(["success": .bool(true)])
        } catch {
            logger.error("Error performing swipe: \(error)")
            throw RPCMethodError.internalError("Error performing swipe: \(error.localizedDescription)")
        }
    }

    /// Synthesizes a swipe gesture using private XCTest APIs.
    ///
    /// - Parameters:
    ///   - start: The starting point of the swipe.
    ///   - end: The ending point of the swipe.
    ///   - duration: Duration of the gesture in seconds.
    ///
    /// This uses `EventRecord` and `RunnerDaemonProxy` to send the gesture
    /// to the XCTest runner daemon.
    func swipePrivateAPI(start: CGPoint, end: CGPoint, duration: Double) async throws {
        logger.info("Swipe (v1) from \(start.debugDescription) to \(end.debugDescription) with duration \(duration)")

        let eventRecord = EventRecord(orientation: .portrait)
        _ = eventRecord.addSwipeEvent(start: start, end: end, duration: duration)

        try await RunnerDaemonProxy().synthesize(eventRecord: eventRecord)
    }
}
