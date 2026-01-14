import FlyingFox
import XCTest
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

// MARK: - Tap Route Handler

/// HTTP handler for tap and long-press gesture synthesis.
///
/// This handler processes POST requests to the `/tap` endpoint and synthesizes
/// touch events at the specified screen coordinates using XCTest private APIs.
///
/// ## Endpoint
/// - **Method**: POST
/// - **Path**: `/tap`
/// - **Content-Type**: `application/json`
///
/// ## Request Format
/// ```json
/// {
///   "x": 100.0,
///   "y": 200.0,
///   "duration": null
/// }
/// ```
///
/// | Field | Type | Required | Description |
/// |-------|------|----------|-------------|
/// | `x` | Float | Yes | X coordinate in screen points |
/// | `y` | Float | Yes | Y coordinate in screen points |
/// | `duration` | Float | No | Duration for long-press (omit or null for tap) |
///
/// ## Response
/// - **200 OK**: Tap performed successfully (empty body)
/// - **400 Bad Request**: Invalid request body
/// - **500 Internal Server Error**: Event synthesis failed
///
/// ## curl Examples
/// ```bash
/// # Simple tap
/// curl -X POST http://127.0.0.1:12004/tap \
///     -H "Content-Type: application/json" \
///     -d '{"x": 100.0, "y": 200.0}'
///
/// # Long-press for 2 seconds
/// curl -X POST http://127.0.0.1:12004/tap \
///     -H "Content-Type: application/json" \
///     -d '{"x": 150.0, "y": 300.0, "duration": 2.0}'
/// ```
///
/// ## Implementation Details
/// - Coordinates are automatically adjusted for device orientation
/// - Uses `EventRecord` and `RunnerDaemonProxy` for event synthesis
/// - Long-press is achieved by setting `touchUpAfter` duration
@MainActor
struct TapHandler: HTTPHandler {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Handles incoming tap requests.
    ///
    /// - Parameter request: The HTTP request containing tap coordinates.
    /// - Returns: HTTP 200 on success, or an error response on failure.
    func handleRequest(_ request: FlyingFox.HTTPRequest) async throws -> FlyingFox.HTTPResponse {
        let decoder = JSONDecoder()

        guard let requestBody = try? await decoder.decode(TapRequest.self, from: request.bodyData) else {
            NSLog("Invalid request for tapping")
            return ServerError(type: .precondition, message: "incorrect request body provided for tap route").httpResponse
        }

        let (width, height) = OrientationGeometry.physicalScreenSize()
        let point = OrientationGeometry.orientationAwarePoint(
            width: width,
            height: height,
            point: CGPoint(x: CGFloat(requestBody.x), y: CGFloat(requestBody.y))
        )
        let (x, y) = (point.x, point.y)

        if requestBody.duration != nil {
            NSLog("Long pressing \(x), \(y) for \(requestBody.duration!)s")
        } else {
            NSLog("Tapping \(x), \(y)")
        }

        do {
            let eventRecord = EventRecord(orientation: .portrait)
            _ = eventRecord.addPointerTouchEvent(
                at: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                touchUpAfter: requestBody.duration
            )
            let start = Date()
            try await RunnerDaemonProxy().synthesize(eventRecord: eventRecord)
            let duration = Date().timeIntervalSince(start)
            NSLog("Tapping took \(duration)")
            return HTTPResponse(statusCode: .ok)
        } catch {
            NSLog("Error tapping: \(error)")
            return ServerError(message: "Error tapping point: \(error.localizedDescription)").httpResponse
        }
    }
}
