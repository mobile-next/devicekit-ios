import Foundation

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
