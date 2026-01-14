import Foundation
import UIKit

// MARK: - Event Record

/// Wrapper for XCTest's private `XCSynthesizedEventRecord` class.
///
/// This class provides a Swift interface to XCTest's internal event synthesis
/// system, enabling programmatic generation of touch events.
///
/// ## Usage
/// ```swift
/// // Create a tap event
/// let eventRecord = EventRecord(orientation: .portrait)
/// _ = eventRecord.addPointerTouchEvent(at: CGPoint(x: 100, y: 200), touchUpAfter: nil)
///
/// // Create a long-press event (2 seconds)
/// let longPress = EventRecord(orientation: .portrait)
/// _ = longPress.addPointerTouchEvent(at: CGPoint(x: 100, y: 200), touchUpAfter: 2.0)
/// ```
///
/// ## Implementation Details
/// Uses Objective-C runtime to access `XCSynthesizedEventRecord` private API.
@objc
final class EventRecord: NSObject {

    /// The underlying `XCSynthesizedEventRecord` object.
    let eventRecord: NSObject

    /// Default duration for tap touch-down before lift-up (100ms).
    static let defaultTapDuration = 0.1

    /// Touch event styles.
    enum Style: String {
        /// Single finger touch events (tap, long-press, drag).
        case singeFinger = "Single-Finger Touch Action"

        /// Multi-finger touch events (pinch, rotate).
        case multiFinger = "Multi-Finger Touch Action"
    }

    /// Creates a new event record for the specified orientation.
    ///
    /// - Parameters:
    ///   - orientation: The interface orientation for event coordinates.
    ///   - style: The touch style (single or multi-finger).
    init(orientation: UIInterfaceOrientation, style: Style = .singeFinger) {
        eventRecord = objc_lookUpClass("XCSynthesizedEventRecord")?.alloc()
            .perform(
                NSSelectorFromString("initWithName:interfaceOrientation:"),
                with: style.rawValue,
                with: orientation
            )
            .takeUnretainedValue() as! NSObject
    }

    /// Adds a tap or long-press event at the specified point.
    ///
    /// - Parameters:
    ///   - point: The screen coordinates for the touch.
    ///   - touchUpAfter: Duration to hold before lifting (nil for default tap duration).
    /// - Returns: Self for method chaining.
    func addPointerTouchEvent(at point: CGPoint, touchUpAfter: TimeInterval?) -> Self {
        var path = PointerEventPath.pathForTouch(at: point)
        path.offset += touchUpAfter ?? Self.defaultTapDuration
        path.liftUp()
        return add(path)
    }

    /// Adds a pointer event path to this event record.
    ///
    /// - Parameter path: The pointer event path to add.
    /// - Returns: Self for method chaining.
    func add(_ path: PointerEventPath) -> Self {
        let selector = NSSelectorFromString("addPointerEventPath:")
        let imp = eventRecord.method(for: selector)
        typealias Method = @convention(c) (NSObject, Selector, NSObject) -> ()
        let method = unsafeBitCast(imp, to: Method.self)
        method(eventRecord, selector, path.path)
        return self
    }
}
