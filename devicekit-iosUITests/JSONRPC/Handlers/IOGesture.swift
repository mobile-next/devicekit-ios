import Foundation
import os

// MARK: - Action Model

/// Represents a single pointer action in a gesture sequence.
///
/// Actions are grouped by `button` (finger index) and executed in the order they appear.
/// This model is compatible with WDA/Appium pointer actions.
///
/// ## Action Types
/// - `"press"`: Finger touches screen at (x, y). Duration specifies hold time before next action.
/// - `"move"`: Finger moves to (x, y) over `duration` seconds.
/// - `"release"`: Finger lifts from screen.
///
/// ## Finger Indexing
/// The `button` field identifies which finger performs the action:
/// - `0` = first finger (primary)
/// - `1` = second finger
/// - `2` = third finger, etc.
struct Action: Codable {
    /// Action type: "press", "move", or "release"
    let type: String

    /// Duration in seconds.
    /// - For "press": Hold time before next action (usually 0)
    /// - For "move": Time to interpolate movement
    /// - For "release": Usually 0
    let duration: TimeInterval

    /// X coordinate in screen points
    let x: Float

    /// Y coordinate in screen points
    let y: Float

    /// Finger index: 0 = first finger, 1 = second finger, etc.
    let button: Int
}

// MARK: - Request Model

/// Request parameters for the `io_gesture` JSON-RPC method.
struct IOGestureRequest: Codable {
    /// Target device identifier (unused in direct device connection, kept for API compatibility)
    let deviceId: String

    /// Array of actions representing the complete gesture sequence
    let actions: [Action]
}

// MARK: - Action Type Enum

/// Supported action types for gesture sequences.
private enum ActionType: String {
    case press
    case move
    case release
}

// MARK: - Handler

/// JSON-RPC method handler for complex multi-finger gestures.
///
/// Implements WDA/Appium-compatible pointer actions supporting:
/// - Single and multi-finger gestures
/// - Press, move, and release actions
/// - Duration-based timing for smooth animations
/// - Parallel execution of multiple finger paths
///
/// ## Method Name
/// `io_gesture`
///
/// ## Supported Gestures
/// - **Tap**: press → release
/// - **Long press**: press (with duration) → release
/// - **Swipe**: press → move → release
/// - **Pinch**: Two fingers moving toward/away from center
/// - **Rotate**: Two fingers moving in circular paths
/// - **Multi-finger**: Any combination of fingers with independent paths
///
/// ---
///
/// ## curl Examples
///
/// ### Single-finger swipe (scroll down)
/// ```bash
/// curl -X POST http://127.0.0.1:12004/rpc \
///   -H "Content-Type: application/json" \
///   -d '{
///     "jsonrpc": "2.0",
///     "method": "io_gesture",
///     "params": {
///       "deviceId": "",
///       "actions": [
///         {"type": "press", "x": 200, "y": 600, "duration": 0, "button": 0},
///         {"type": "move", "x": 200, "y": 200, "duration": 0.3, "button": 0},
///         {"type": "release", "x": 200, "y": 200, "duration": 0, "button": 0}
///       ]
///     },
///     "id": 1
///   }'
/// ```
///
/// ### Long press (2 seconds)
/// ```bash
/// curl -X POST http://127.0.0.1:12004/rpc \
///   -H "Content-Type: application/json" \
///   -d '{
///     "jsonrpc": "2.0",
///     "method": "io_gesture",
///     "params": {
///       "deviceId": "",
///       "actions": [
///         {"type": "press", "x": 200, "y": 400, "duration": 2.0, "button": 0},
///         {"type": "release", "x": 200, "y": 400, "duration": 0, "button": 0}
///       ]
///     },
///     "id": 1
///   }'
/// ```
///
/// ### Two-finger pinch-out (zoom in)
/// ```bash
/// curl -X POST http://127.0.0.1:12004/rpc \
///   -H "Content-Type: application/json" \
///   -d '{
///     "jsonrpc": "2.0",
///     "method": "io_gesture",
///     "params": {
///       "deviceId": "",
///       "actions": [
///         {"type": "press", "x": 180, "y": 400, "duration": 0, "button": 0},
///         {"type": "press", "x": 220, "y": 400, "duration": 0, "button": 1},
///         {"type": "move", "x": 100, "y": 400, "duration": 0.4, "button": 0},
///         {"type": "move", "x": 300, "y": 400, "duration": 0.4, "button": 1},
///         {"type": "release", "x": 100, "y": 400, "duration": 0, "button": 0},
///         {"type": "release", "x": 300, "y": 400, "duration": 0, "button": 1}
///       ]
///     },
///     "id": 1
///   }'
/// ```
///
/// ### Two-finger pinch-in (zoom out)
/// ```bash
/// curl -X POST http://127.0.0.1:12004/rpc \
///   -H "Content-Type: application/json" \
///   -d '{
///     "jsonrpc": "2.0",
///     "method": "io_gesture",
///     "params": {
///       "deviceId": "",
///       "actions": [
///         {"type": "press", "x": 100, "y": 400, "duration": 0, "button": 0},
///         {"type": "press", "x": 300, "y": 400, "duration": 0, "button": 1},
///         {"type": "move", "x": 180, "y": 400, "duration": 0.4, "button": 0},
///         {"type": "move", "x": 220, "y": 400, "duration": 0.4, "button": 1},
///         {"type": "release", "x": 180, "y": 400, "duration": 0, "button": 0},
///         {"type": "release", "x": 220, "y": 400, "duration": 0, "button": 1}
///       ]
///     },
///     "id": 1
///   }'
/// ```
///
/// ---
///
/// ## WebSocket Examples
///
/// Connect with: `wscat -c ws://127.0.0.1:12004/rpc`
///
/// ### Single-finger swipe
/// ```json
/// {"jsonrpc":"2.0","method":"io_gesture","params":{"deviceId":"","actions":[{"type":"press","x":200,"y":600,"duration":0,"button":0},{"type":"move","x":200,"y":200,"duration":0.3,"button":0},{"type":"release","x":200,"y":200,"duration":0,"button":0}]},"id":1}
/// ```
///
/// ### Long press
/// ```json
/// {"jsonrpc":"2.0","method":"io_gesture","params":{"deviceId":"","actions":[{"type":"press","x":200,"y":400,"duration":2.0,"button":0},{"type":"release","x":200,"y":400,"duration":0,"button":0}]},"id":1}
/// ```
///
/// ### Two-finger pinch-out (zoom in)
/// ```json
/// {"jsonrpc":"2.0","method":"io_gesture","params":{"deviceId":"","actions":[{"type":"press","x":180,"y":400,"duration":0,"button":0},{"type":"press","x":220,"y":400,"duration":0,"button":1},{"type":"move","x":100,"y":400,"duration":0.4,"button":0},{"type":"move","x":300,"y":400,"duration":0.4,"button":1},{"type":"release","x":100,"y":400,"duration":0,"button":0},{"type":"release","x":300,"y":400,"duration":0,"button":1}]},"id":1}
/// ```
///
/// ### Two-finger pinch-in (zoom out)
/// ```json
/// {"jsonrpc":"2.0","method":"io_gesture","params":{"deviceId":"","actions":[{"type":"press","x":100,"y":400,"duration":0,"button":0},{"type":"press","x":300,"y":400,"duration":0,"button":1},{"type":"move","x":180,"y":400,"duration":0.4,"button":0},{"type":"move","x":220,"y":400,"duration":0.4,"button":1},{"type":"release","x":180,"y":400,"duration":0,"button":0},{"type":"release","x":220,"y":400,"duration":0,"button":1}]},"id":1}
/// ```
///
/// ---
///
/// ## Response
/// ```json
/// {
///   "jsonrpc": "2.0",
///   "result": { "success": true },
///   "id": 1
/// }
/// ```
///
/// ## Errors
/// - `-32602`: Invalid parameters (validation failures)
/// - `-32603`: Internal error (gesture synthesis failed)
@MainActor
struct IOGestureMethodHandler: RPCMethodHandler {

    /// The JSON-RPC method name this handler responds to.
    static let methodName = "io_gesture"

    /// Minimum hold duration after press to ensure touch registration
    private static let minimumPressHoldDuration: TimeInterval = 0.05

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Executes the `io_gesture` JSON-RPC method.
    ///
    /// - Parameter params: JSON-RPC parameters containing the gesture actions.
    /// - Returns: A JSON object `{ "success": true }` on success.
    /// - Throws: `RPCMethodError` if validation fails or gesture cannot be synthesized.
    func execute(params: JSONValue?) async throws -> JSONValue {
        // 1. Validate params exist
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for io_gesture method")
        }

        // 2. Decode request
        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: IOGestureRequest
        do {
            request = try JSONDecoder().decode(IOGestureRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid io_gesture parameters: \(error.localizedDescription)")
        }

        // 3. Validate actions array is not empty
        guard !request.actions.isEmpty else {
            throw RPCMethodError.invalidParams("Actions array cannot be empty")
        }

        // 4. Group actions by finger index (button)
        let fingerActions = groupActionsByFinger(request.actions)
        logger.info("Gesture has \(fingerActions.count) finger(s)")

        // 5. Validate each finger's action sequence
        for (fingerIndex, actions) in fingerActions {
            try validateFingerSequence(actions, fingerIndex: fingerIndex)
        }

        // 6. Execute the gesture
        do {
            let start = Date()
            try await executeGesture(fingerActions: fingerActions)
            let duration = Date().timeIntervalSince(start)
            logger.info("Gesture execution completed in \(duration)s")
            return .object(["success": .bool(true)])
        } catch let error as RPCMethodError {
            throw error
        } catch {
            logger.error("Error executing gesture: \(error)")
            throw RPCMethodError.internalError("Gesture execution failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Groups actions by finger index while preserving order within each finger.
    ///
    /// - Parameter actions: The flat array of actions from the request.
    /// - Returns: Dictionary mapping finger index to ordered array of actions.
    private func groupActionsByFinger(_ actions: [Action]) -> [Int: [Action]] {
        var grouped: [Int: [Action]] = [:]
        for action in actions {
            grouped[action.button, default: []].append(action)
        }
        return grouped
    }

    /// Validates that a finger's action sequence follows the required rules.
    ///
    /// ## Validation Rules
    /// - Sequence must start with "press"
    /// - "move" actions may only occur after a press
    /// - Sequence must end with "release"
    /// - Only one "press" per finger
    /// - Coordinates must be non-negative
    /// - Duration must be non-negative
    ///
    /// - Parameters:
    ///   - actions: The ordered array of actions for this finger.
    ///   - fingerIndex: The finger index for error messages.
    /// - Throws: `RPCMethodError.invalidParams` if validation fails.
    private func validateFingerSequence(_ actions: [Action], fingerIndex: Int) throws {
        guard !actions.isEmpty else {
            throw RPCMethodError.invalidParams("Finger \(fingerIndex) has no actions")
        }

        // Must start with press
        guard actions.first?.type == ActionType.press.rawValue else {
            throw RPCMethodError.invalidParams(
                "Finger \(fingerIndex) must start with 'press' action, got '\(actions.first?.type ?? "nil")'"
            )
        }

        // Must end with release
        guard actions.last?.type == ActionType.release.rawValue else {
            throw RPCMethodError.invalidParams(
                "Finger \(fingerIndex) must end with 'release' action, got '\(actions.last?.type ?? "nil")'"
            )
        }

        // Validate sequence order and values
        var hasPressed = false
        var hasReleased = false

        for (index, action) in actions.enumerated() {
            // Validate action type
            guard let actionType = ActionType(rawValue: action.type) else {
                throw RPCMethodError.invalidParams(
                    "Unknown action type '\(action.type)' for finger \(fingerIndex) at index \(index)"
                )
            }

            // Validate coordinates are non-negative
            guard action.x >= 0 && action.y >= 0 else {
                throw RPCMethodError.invalidParams(
                    "Negative coordinates (\(action.x), \(action.y)) for finger \(fingerIndex) at index \(index)"
                )
            }

            // Validate duration is non-negative
            guard action.duration >= 0 else {
                throw RPCMethodError.invalidParams(
                    "Negative duration \(action.duration) for finger \(fingerIndex) at index \(index)"
                )
            }

            switch actionType {
            case .press:
                if hasPressed {
                    throw RPCMethodError.invalidParams(
                        "Finger \(fingerIndex) has multiple 'press' actions"
                    )
                }
                hasPressed = true

            case .move:
                if !hasPressed {
                    throw RPCMethodError.invalidParams(
                        "Finger \(fingerIndex) has 'move' before 'press' at index \(index)"
                    )
                }
                if hasReleased {
                    throw RPCMethodError.invalidParams(
                        "Finger \(fingerIndex) has 'move' after 'release' at index \(index)"
                    )
                }

            case .release:
                if !hasPressed {
                    throw RPCMethodError.invalidParams(
                        "Finger \(fingerIndex) has 'release' before 'press' at index \(index)"
                    )
                }
                if hasReleased {
                    throw RPCMethodError.invalidParams(
                        "Finger \(fingerIndex) has multiple 'release' actions"
                    )
                }
                if index != actions.count - 1 {
                    throw RPCMethodError.invalidParams(
                        "Finger \(fingerIndex) has 'release' before end of sequence at index \(index)"
                    )
                }
                hasReleased = true
            }
        }
    }

    /// Executes the multi-finger gesture by building event paths and synthesizing them.
    ///
    /// All finger paths are added to a single EventRecord and synthesized together,
    /// ensuring proper synchronization of multi-finger gestures.
    ///
    /// - Parameter fingerActions: Dictionary of finger index to action arrays.
    /// - Throws: Error if gesture synthesis fails.
    private func executeGesture(fingerActions: [Int: [Action]]) async throws {
        // Determine if this is a multi-finger gesture
        let isMultiFinger = fingerActions.count > 1
        let style: EventRecord.Style = isMultiFinger ? .multiFinger : .singeFinger

        // Create event record with appropriate style
        let eventRecord = EventRecord(orientation: .portrait, style: style)

        // Get screen dimensions for coordinate transformation
        let (screenWidth, screenHeight) = OrientationGeometry.physicalScreenSize()

        // Build paths for each finger, sorted by finger index for deterministic ordering
        for (fingerIndex, actions) in fingerActions.sorted(by: { $0.key < $1.key }) {
            logger.info("Building path for finger \(fingerIndex) with \(actions.count) actions")
            try buildFingerPath(
                actions: actions,
                fingerIndex: fingerIndex,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                eventRecord: eventRecord
            )
        }

        // Synthesize all finger paths in parallel
        logger.info("Synthesizing gesture with \(fingerActions.count) finger path(s)")
        try await RunnerDaemonProxy().synthesize(eventRecord: eventRecord)
    }

    /// Builds the event path for a single finger and adds it to the event record.
    ///
    /// The path is constructed by:
    /// 1. Creating a touch-down at the press location
    /// 2. Adding move events with proper time offsets
    /// 3. Ending with a lift-up at the release location
    ///
    /// - Parameters:
    ///   - actions: The ordered array of actions for this finger.
    ///   - fingerIndex: The finger index for logging.
    ///   - screenWidth: Screen width for coordinate transformation.
    ///   - screenHeight: Screen height for coordinate transformation.
    ///   - eventRecord: The event record to add the path to.
    /// - Throws: Error if path construction fails.
    private func buildFingerPath(
        actions: [Action],
        fingerIndex: Int,
        screenWidth: Float,
        screenHeight: Float,
        eventRecord: EventRecord
    ) throws {
        guard let pressAction = actions.first else {
            throw RPCMethodError.invalidParams("Finger \(fingerIndex) has no actions")
        }

        // Transform the initial press coordinates to screen space
        let initialPoint = OrientationGeometry.orientationAwarePoint(
            width: screenWidth,
            height: screenHeight,
            point: CGPoint(x: CGFloat(pressAction.x), y: CGFloat(pressAction.y))
        )

        // Track cumulative time offset for this finger's path
        var currentOffset: TimeInterval = 0

        // Create the path starting at the press location
        var path = PointerEventPath.pathForTouch(at: initialPoint, offset: currentOffset)

        // Add minimum hold duration after press to ensure touch registration
        currentOffset += max(pressAction.duration, Self.minimumPressHoldDuration)

        // Process remaining actions (moves and release)
        for action in actions.dropFirst() {
            // Transform coordinates
            let point = OrientationGeometry.orientationAwarePoint(
                width: screenWidth,
                height: screenHeight,
                point: CGPoint(x: CGFloat(action.x), y: CGFloat(action.y))
            )

            guard let actionType = ActionType(rawValue: action.type) else {
                continue // Already validated, skip unknown types
            }

            switch actionType {
            case .press:
                // Should not happen - already validated only one press per finger
                break

            case .move:
                // Update the offset to include this move's duration
                currentOffset += action.duration
                path.offset = currentOffset
                // Move to the new position
                path.moveTo(point: point)
                logger.debug("Finger \(fingerIndex): move to (\(point.x), \(point.y)) at offset \(currentOffset)s")

            case .release:
                // Add any release duration (usually 0)
                currentOffset += action.duration
                path.offset = currentOffset
                // Lift the finger
                path.liftUp()
                logger.debug("Finger \(fingerIndex): release at offset \(currentOffset)s")
            }
        }

        // Add the completed path to the event record
        _ = eventRecord.add(path)
        logger.info("Finger \(fingerIndex): path completed, total duration \(currentOffset)s")
    }
}
