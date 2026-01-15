import Foundation

// MARK: - Pointer Event Path

/// Wrapper for XCTest's private `XCPointerEventPath` class.
///
/// Represents a sequence of touch events (touch down, move, lift up) that form
/// a complete gesture path. Used by `EventRecord` to construct touch events.
///
/// ## Usage
/// ```swift
/// // Create a tap path
/// var tapPath = PointerEventPath.pathForTouch(at: CGPoint(x: 100, y: 200))
/// tapPath.offset += 0.1  // Hold for 100ms
/// tapPath.liftUp()
///
/// ```
///
/// ## Implementation Details
/// Uses Objective-C runtime to access `XCPointerEventPath` private API.
struct PointerEventPath {

    /// Creates a touch path starting at the specified point.
    ///
    /// - Parameters:
    ///   - point: The initial touch-down location.
    ///   - offset: Initial time offset in seconds.
    /// - Returns: A new pointer event path.
    static func pathForTouch(at point: CGPoint, offset: TimeInterval = 0)
        -> Self
    {
        let alloced =
            objc_lookUpClass("XCPointerEventPath")!.alloc() as! NSObject
        let selector = NSSelectorFromString("initForTouchAtPoint:offset:")
        let imp = alloced.method(for: selector)
        typealias Method =
            @convention(c) (NSObject, Selector, CGPoint, TimeInterval) ->
            NSObject
        let method = unsafeBitCast(imp, to: Method.self)
        let path = method(alloced, selector, point, offset)
        return Self(path: path, offset: offset)
    }

    /// The underlying `XCPointerEventPath` object.
    let path: NSObject

    /// Current time offset for the next event in the path.
    var offset: TimeInterval

    private init(path: NSObject, offset: TimeInterval) {
        self.path = path
        self.offset = offset
    }

    /// Lifts the touch at the current offset time.
    ///
    /// Call this to complete a touch gesture (touch-up event).
    mutating func liftUp() {
        let selector = NSSelectorFromString("liftUpAtOffset:")
        let imp = path.method(for: selector)
        typealias Method =
            @convention(c) (NSObject, Selector, TimeInterval) -> Void
        let method = unsafeBitCast(imp, to: Method.self)
        method(path, selector, offset)
    }
}
