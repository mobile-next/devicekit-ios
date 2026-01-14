import Foundation
import XCTest

// MARK: - Event Target

/// Wrapper for XCTest's event dispatch system.
///
/// Provides an alternative to `RunnerDaemonProxy` for dispatching events
/// directly to the foreground application's event target.
///
/// ## Usage
/// ```swift
/// let target = EventTarget()
/// try await target.dispatchEvent(description: "Tap button") {
///     let record = EventRecord(orientation: .portrait)
///     _ = record.addPointerTouchEvent(at: CGPoint(x: 100, y: 200), touchUpAfter: nil)
///     return record
/// }
/// ```
///
/// ## Implementation Details
/// Uses Objective-C runtime to access the private `eventTarget` property.
@MainActor
struct EventTarget {

    /// The underlying event target object.
    let eventTarget: NSObject

    /// Creates an event target for the current foreground application.
    ///
    /// Falls back to SpringBoard if no foreground app is detected.
    init() {
        let application = RunningApp.getForegroundApp() ?? XCUIApplication(bundleIdentifier: RunningApp.springboardBundleId)

        eventTarget = application.children(matching: .any).firstMatch
            .perform(NSSelectorFromString("eventTarget"))
            .takeUnretainedValue() as! NSObject
    }

    /// Block type for building event records.
    typealias EventBuilder = @convention(block) () -> EventRecord

    /// Dispatches an event using the provided builder.
    ///
    /// - Parameters:
    ///   - description: Description of the event for logging.
    ///   - builder: Closure that creates and returns an `EventRecord`.
    /// - Throws: An error if event dispatch fails.
    func dispatchEvent(description: String, builder: EventBuilder) async throws {
        let selector = NSSelectorFromString("dispatchEventWithDescription:eventBuilder:error:")
        let imp = eventTarget.method(for: selector)

        typealias EventBuilderObjc = @convention(block) () -> NSObject
        typealias Method = @convention(c) (NSObject, Selector, String, EventBuilderObjc, AutoreleasingUnsafeMutablePointer<NSError?>) -> Bool
        var error: NSError?
        let method = unsafeBitCast(imp, to: Method.self)

        _ = method(
            eventTarget,
            selector,
            description,
            { builder().eventRecord },
            &error
        )

        if let error = error {
            throw error
        }
    }
}
