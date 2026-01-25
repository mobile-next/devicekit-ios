import FlyingFox
import XCTest
import os

// MARK: - Constants

/// Configuration constants for text input behavior.
private enum Constants {
    /// Default typing frequency for bulk text input (characters per second).
    /// Higher values result in faster typing but may cause iOS to drop characters.
    static let typingFrequency = 30

    /// Number of initial characters to type at a slower speed.
    /// This helps avoid character drops due to keyboard listeners (autocorrection, etc.).
    static let slowInputCharactersCount = 1
}

// MARK: - Request Model

/// Parameters for the `io_text` JSON-RPC method.
///
/// ## JSON Format
/// ```json
/// {
///   "text": "Hello, World!",
///   "deviceId": "ID"
/// }
/// ```
///
/// ## Fields
/// - `text`: The text string to input into the currently focused text field.
/// - `deviceId`: Reserved for future use. Currently unused but required for API compatibility.
///
/// ## Example Request
/// ```json
/// {
///   "jsonrpc": "2.0",
///   "method": "io_text",
///   "params": {
///     "text": "test@example.com",
///     "deviceId": "your_device_id"
///   },
///   "id": 1
/// }
/// ```
struct IOTextRequest: Codable {
    /// The text to input into the focused text field.
    let text: String

    /// Reserved for future use. Pass an empty array.
    let deviceId: String
}

// MARK: - Handler

/// JSON-RPC method handler for text input operations.
///
/// This handler synthesizes keyboard input events to type text into the currently
/// focused text field on the device. It uses XCTest's private APIs to generate
/// authentic keyboard events.
///
/// ## Method Name
/// `io_text`
///
/// ## Prerequisites
/// - A text field must be focused and the keyboard must be visible.
/// - The handler waits up to 1 second for the keyboard to appear.
///
/// ## Implementation Notes
/// To avoid iOS dropping characters (a common issue with synthetic keyboard input),
/// the handler uses a two-phase approach:
/// 1. Types the first character at a slow speed (frequency = 1)
/// 2. Waits 500ms for iOS to stabilize
/// 3. Types remaining characters at normal speed (frequency = 30)
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
/// - `-32602`: Invalid parameters (missing or malformed request)
/// - `-32603`: Internal error (keyboard not visible, text input failed)
@MainActor
struct IOTextMethodHandler: RPCMethodHandler {

    /// The JSON-RPC method name this handler responds to.
    static let methodName = "io_text"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Executes the text input operation.
    ///
    /// - Parameter params: JSON-RPC parameters containing the text to input.
    /// - Returns: A JSON object with `success: true` on successful input.
    /// - Throws: `RPCMethodError.invalidParams` if parameters are invalid,
    ///           `RPCMethodError.internalError` if text input fails.
    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for io_text method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: IOTextRequest
        do {
            request = try JSONDecoder().decode(IOTextRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid io_text parameters: \(error.localizedDescription)")
        }

        do {
            let start = Date()

            await waitUntilKeyboardIsPresented()

            try await inputText(request.text)

            let duration = Date().timeIntervalSince(start)
            logger.info("Text input duration took \(duration)")
            return .object(["success": .bool(true)])
        } catch {
            logger.error("Error inputting text: \(error)")
            throw RPCMethodError.internalError("Error inputting text: \(error.localizedDescription)")
        }
    }

    /// Waits for the keyboard to become visible on screen.
    ///
    /// Polls every 200ms for up to 1 second checking if any keyboard is present
    /// in the foreground application or SpringBoard.
    private func waitUntilKeyboardIsPresented() async {
        try? await repeatUntil(timeout: 1, delta: 0.2) {
            let app = RunningApp.getForegroundApp() ?? XCUIApplication(bundleIdentifier: RunningApp.springboardBundleId)

            return app.keyboards.firstMatch.exists
        }
    }

    /// Synthesizes keyboard input events to type the given text.
    ///
    /// Uses a two-phase approach to avoid character drops:
    /// 1. **Phase 1**: Types the first character at speed 1 (slowest)
    /// 2. **Delay**: Waits 500ms for iOS input system to stabilize
    /// 3. **Phase 2**: Types remaining characters at normal speed (30 chars/sec)
    ///
    /// - Parameter text: The text string to type.
    /// - Throws: Error if event synthesis fails.
    private func inputText(_ text: String) async throws {
        // Due to different keyboard input listener events (i.e. autocorrection or hardware keyboard connection)
        // characters after the first one are often skipped, so we'll input it with lower typing frequency
        let firstCharacter = String(text.prefix(Constants.slowInputCharactersCount))
        logger.info("first character: \(firstCharacter)")
        var eventPath = PointerEventPath.pathForTextInput()
        eventPath.type(text: firstCharacter, typingSpeed: 1)
        let eventRecord = EventRecord(orientation: .portrait)
        _ = eventRecord.add(eventPath)
        try await RunnerDaemonProxy().synthesize(eventRecord: eventRecord)

        // Wait 500ms before dispatching next input text request to avoid iOS dropping characters
        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * 0.5))

        if text.count > Constants.slowInputCharactersCount {
            let remainingText = String(text.suffix(text.count - Constants.slowInputCharactersCount))
            logger.info("remaining text: \(remainingText)")
            var eventPath2 = PointerEventPath.pathForTextInput()
            eventPath2.type(text: remainingText, typingSpeed: Constants.typingFrequency)
            let eventRecord2 = EventRecord(orientation: .portrait)
            _ = eventRecord2.add(eventPath2)
            try await RunnerDaemonProxy().synthesize(eventRecord: eventRecord2)
        }
    }

    /// Repeatedly executes a block until it returns `true` or the timeout expires.
    ///
    /// - Parameters:
    ///   - timeout: Maximum time to wait in seconds.
    ///   - delta: Interval between checks in seconds.
    ///   - block: Closure that returns `true` when the condition is met.
    /// - Throws: Error if delta is negative or if the task sleep fails.
    func repeatUntil(timeout: TimeInterval, delta: TimeInterval, block: () -> Bool) async throws {
        guard delta >= 0 else {
            throw NSError(domain: "Invalid value", code: 1, userInfo: [NSLocalizedDescriptionKey: "Delta cannot be negative"])
        }

        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            do {
                try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * delta))
            } catch {
                throw NSError(domain: "Failed to sleep task", code: 2, userInfo: [NSLocalizedDescriptionKey: "Task could not be put to sleep"])
            }

            if block() {
                break
            }
        }
    }
}
