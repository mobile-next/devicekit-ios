import Foundation

// MARK: - Runner Daemon Proxy

/// Proxy for XCTest's daemon session to synthesize UI events.
///
/// This class provides access to XCTest's internal daemon session, enabling
/// programmatic event synthesis for UI automation.
///
/// ## Usage
/// ```swift
/// let proxy = RunnerDaemonProxy()
///
/// // Synthesize a tap event
/// let eventRecord = EventRecord(orientation: .portrait)
/// _ = eventRecord.addPointerTouchEvent(at: CGPoint(x: 100, y: 200), touchUpAfter: nil)
/// try await proxy.synthesize(eventRecord: eventRecord)
///
/// // Send text input
/// try await proxy.send(string: "Hello World", typingFrequency: 60)
/// ```
///
/// ## Implementation Details
/// Uses Objective-C runtime to access `XCTRunnerDaemonSession` private API.
@MainActor
class RunnerDaemonProxy {

    /// The underlying daemon proxy object.
    private let proxy: NSObject

    /// Creates a new runner daemon proxy.
    ///
    /// Accesses the shared XCTest daemon session and retrieves its proxy.
    init() {
        let clazz: AnyClass = NSClassFromString("XCTRunnerDaemonSession")!
        let selector = NSSelectorFromString("sharedSession")
        let imp = clazz.method(for: selector)
        typealias Method = @convention(c) (AnyClass, Selector) -> NSObject
        let method = unsafeBitCast(imp, to: Method.self)
        let session = method(clazz, selector)

        proxy =
            session
            .perform(NSSelectorFromString("daemonProxy"))
            .takeUnretainedValue() as! NSObject
    }

    /// Sends a string as keyboard input.
    ///
    /// - Parameters:
    ///   - string: The text to type.
    ///   - typingFrequency: Maximum characters per second (default: 10).
    /// - Throws: An error if the text input fails.
    func send(string: String, typingFrequency: Int = 10) async throws {
        let selector = NSSelectorFromString(
            "_XCT_sendString:maximumFrequency:completion:"
        )
        let imp = proxy.method(for: selector)
        typealias Method =
            @convention(c) (
                NSObject, Selector, NSString, Int, @escaping (Error?) -> Void
            ) -> Void
        let method = unsafeBitCast(imp, to: Method.self)
        return try await withCheckedThrowingContinuation { continuation in
            method(
                proxy,
                selector,
                string as NSString,
                typingFrequency,
                { error in
                    if let error = error {
                        continuation.resume(with: .failure(error))
                    } else {
                        continuation.resume(with: .success(()))
                    }
                }
            )
        }
    }

    /// Synthesizes a touch event from an event record.
    ///
    /// - Parameter eventRecord: The event record containing touch events to synthesize.
    /// - Throws: An error if event synthesis fails.
    func synthesize(eventRecord: EventRecord) async throws {
        let selector = NSSelectorFromString("_XCT_synthesizeEvent:completion:")
        let imp = proxy.method(for: selector)
        typealias Method =
            @convention(c) (
                NSObject, Selector, NSObject, @escaping (Error?) -> Void
            ) -> Void
        let method = unsafeBitCast(imp, to: Method.self)
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            method(
                proxy,
                selector,
                eventRecord.eventRecord,
                { error in
                    if let error = error {
                        continuation.resume(with: .failure(error))
                    } else {
                        continuation.resume(with: .success(()))
                    }
                }
            )
        }
    }
}
