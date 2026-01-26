import os

// MARK: - Tap Request Model

/// Request body for the `/io_longpress` endpoint.
///
/// This model represents the JSON payload for long-press gestures.
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
struct IOLongpressRequest: Codable {

    /// X coordinate in screen points.
    let x: Float

    /// Y coordinate in screen points.
    let y: Float

    /// Duration in seconds for long-press gestures.
    /// - `nil` or omitted: Performs a simple tap.
    /// - Non-nil value: Performs a long-press for the specified duration.
    let duration: TimeInterval
}

// MARK: - Tap Method Handler

/// JSON-RPC handler for the `io_longpress` method.
///
/// Performs tap or long-press gestures at screen coordinates.
///
/// ## Parameters
/// ```json
/// {
///   "x": 100,
///   "y": 200,
///   "duration": 2
/// }
/// ```
///
/// ## Result
/// ```json
/// {"success": true}
/// ```
@MainActor
struct IOLongpressMethodHandler: RPCMethodHandler {
    static let methodName = "io_longpress"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Executes the `io_longpress` JSON‑RPC method.
    ///
    /// - Parameter params: The JSON‑RPC parameters containing longpress coordinates and duration.
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

        let request: IOLongpressRequest
        do {
            request = try JSONDecoder().decode(IOLongpressRequest.self, from: paramsData)
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

        logger.info("Long pressing \(x), \(y) for \(request.duration)s")

        do {
            let eventRecord = EventRecord(orientation: .portrait)
            _ = eventRecord.addPointerTouchEvent(
                at: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                touchUpAfter: request.duration
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
