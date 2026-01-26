import os

// MARK: - Tap Request Model

/// Request body for the `/io_tap` endpoint.
///
/// This model represents the JSON payload for tap gestures.
///
/// ## JSON Format
/// ```json
/// {
///   "x": 100.0,
///   "y": 200.0,
///   "duration": null
/// }
/// ```
///
struct IOTapRequest: Codable {
    /// The target device identifier.
    let deviceId: String

    /// X coordinate in screen points.
    let x: Float

    /// Y coordinate in screen points.
    let y: Float
}

// MARK: - Tap Method Handler

/// JSON-RPC handler for the `io_tap` method.
///
/// Performs tap or long-press gestures at screen coordinates.
///
/// ## Parameters
/// ```json
/// {
///   "x": 100.0,
///   "y": 200.0,
///   "duration": null
/// }
/// ```
///
/// ## Result
/// ```json
/// {"success": true}
/// ```
@MainActor
struct IOTapMethodHandler: RPCMethodHandler {
    static let methodName = "io_tap"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Executes the `io_tap` JSON‑RPC method.
    ///
    /// - Parameter params: The JSON‑RPC parameters containing tap coordinates.
    /// - Returns: A JSON object `{ "success": true }` on success.
    /// - Throws: `RPCMethodError` if decoding fails or the gesture cannot be synthesized.
    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for io_tap method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: IOTapRequest
        do {
            request = try JSONDecoder().decode(IOTapRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid io_tap parameters: \(error.localizedDescription)")
        }

        let (width, height) = OrientationGeometry.physicalScreenSize()
        let point = OrientationGeometry.orientationAwarePoint(
            width: width,
            height: height,
            point: CGPoint(x: CGFloat(request.x), y: CGFloat(request.y))
        )
        let (x, y) = (point.x, point.y)

        do {
            let eventRecord = EventRecord(orientation: .portrait)
            _ = eventRecord.addPointerTouchEvent(
                at: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                touchUpAfter: nil
            )
            let start = Date()
            try await RunnerDaemonProxy().synthesize(eventRecord: eventRecord)
            let duration = Date().timeIntervalSince(start)
            logger.info("Tapping took \(duration)")
            return .object(["success": .bool(true)])
        } catch {
            logger.error("Error tapping: \(error)")
            throw RPCMethodError.internalError("Error tapping point: \(error.localizedDescription)")
        }
    }
}

