import os

// MARK: - Tap Request Model

/// Request body for the `/tap` endpoint.
///
/// This model represents the JSON payload for tap and long-press gestures.
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
/// ## curl Example
/// ```bash
/// # Simple tap
// curl -X POST http://127.0.0.1:12004/tap \
//     -H "Content-Type: application/json" \
//     -d '{"x": 100.0, "y": 200.0}'
///
/// # Long-press for 1.5 seconds
/// curl -X POST http://127.0.0.1:12004/tap \
///     -H "Content-Type: application/json" \
///     -d '{"x": 100.0, "y": 200.0, "duration": 1.5}'
/// ```
struct TapRequest: Codable {

    /// X coordinate in screen points.
    let x: Float

    /// Y coordinate in screen points.
    let y: Float

    /// Duration in seconds for long-press gestures.
    /// - `nil` or omitted: Performs a simple tap.
    /// - Non-nil value: Performs a long-press for the specified duration.
    let duration: TimeInterval?
}

// MARK: - Tap Method Handler

/// JSON-RPC handler for the `tap` method.
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
struct TapMethodHandler: RPCMethodHandler {
    static let methodName = "tap"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for tap method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: TapRequest
        do {
            request = try JSONDecoder().decode(TapRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid tap parameters: \(error.localizedDescription)")
        }

        let (width, height) = OrientationGeometry.physicalScreenSize()
        let point = OrientationGeometry.orientationAwarePoint(
            width: width,
            height: height,
            point: CGPoint(x: CGFloat(request.x), y: CGFloat(request.y))
        )
        let (x, y) = (point.x, point.y)

        if request.duration != nil {
            NSLog("Long pressing \(x), \(y) for \(request.duration!)s")
        } else {
            NSLog("Tapping \(x), \(y)")
        }

        do {
            let eventRecord = EventRecord(orientation: .portrait)
            _ = eventRecord.addPointerTouchEvent(
                at: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                touchUpAfter: request.duration
            )
            let start = Date()
            try await RunnerDaemonProxy().synthesize(eventRecord: eventRecord)
            let duration = Date().timeIntervalSince(start)
            NSLog("Tapping took \(duration)")
            return .object(["success": .bool(true)])
        } catch {
            NSLog("Error tapping: \(error)")
            throw RPCMethodError.internalError("Error tapping point: \(error.localizedDescription)")
        }
    }
}

