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

    /// Creates a pointer event path configured for text input.
    ///
    /// This initializes an `XCPointerEventPath` using the private `initForTextInput`
    /// selector, which prepares the path for keyboard event synthesis rather than
    /// touch events.
    ///
    /// - Parameter offset: Initial time offset in seconds (default: 0).
    /// - Returns: A new pointer event path configured for text input.
    ///
    /// ## Usage
    /// ```swift
    /// var textPath = PointerEventPath.pathForTextInput()
    /// textPath.type(text: "Hello", typingSpeed: 30)
    /// ```
    static func pathForTextInput(offset: TimeInterval = 0) -> Self {
        let alloced = objc_lookUpClass("XCPointerEventPath")!.alloc() as! NSObject
        let selector = NSSelectorFromString("initForTextInput")
        let imp = alloced.method(for: selector)
        typealias Method = @convention(c) (NSObject, Selector) -> NSObject
        let method = unsafeBitCast(imp, to: Method.self)
        let path = method(alloced, selector)
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

    /// Moves the active touch in the pointer event path to a new screen coordinate.
    ///
    /// This method dynamically invokes the private XCTest selector
    /// `moveToPoint:atOffset:` on the underlying `PointerEventPath` instance.
    /// The selector updates the touch location at the current gesture time offset,
    /// effectively extending the gesture with a movement segment.
    ///
    /// Because the selector is not exposed in Swift, the implementation retrieves
    /// the Objective‑C method IMP at runtime and bridges it to a callable function
    /// using `unsafeBitCast`.
    ///
    /// - Parameter point: The new touch location in screen coordinates.
    ///
    /// - Note:
    ///   The movement occurs at the current `offset` value, which represents the
    ///   accumulated gesture time. Callers are responsible for adjusting `offset`
    ///   before invoking this method to control the timing of the gesture.
    mutating func moveTo(point: CGPoint) {
        let selector = NSSelectorFromString("moveToPoint:atOffset:")
        let imp = path.method(for: selector)
        typealias Method = @convention(c) (NSObject, Selector, CGPoint, TimeInterval) -> ()
        let method = unsafeBitCast(imp, to: Method.self)
        method(path, selector, point, offset)
    }

    /// Synthesizes keyboard events to type the specified text.
    ///
    /// Uses XCTest's private `typeText:atOffset:typingSpeed:shouldRedact:` API
    /// to generate authentic keyboard input events.
    ///
    /// - Parameters:
    ///   - text: The text string to type.
    ///   - typingSpeed: Characters per second. Higher values type faster but may
    ///     cause iOS to drop characters. Recommended: 1 for first character, 30 for rest.
    ///   - shouldRedact: If `true`, redacts the text in logs/traces for sensitive input.
    ///
    /// ## Typing Speed Guidelines
    /// - Speed 1: Very slow, most reliable for initial character
    /// - Speed 30: Normal typing speed, good balance of speed and reliability
    /// - Speed 60+: Fast, may cause character drops on some devices
    ///
    /// ## Example
    /// ```swift
    /// var path = PointerEventPath.pathForTextInput()
    /// path.type(text: "password123", typingSpeed: 30, shouldRedact: true)
    /// ```
    mutating func type(text: String, typingSpeed: Int, shouldRedact: Bool = false) {
        let selector = NSSelectorFromString("typeText:atOffset:typingSpeed:shouldRedact:")
        let imp = path.method(for: selector)
        typealias Method = @convention(c) (NSObject, Selector, NSString, TimeInterval, UInt64, Bool) -> ()
        let method = unsafeBitCast(imp, to: Method.self)
        method(path, selector, text as NSString, offset, UInt64(typingSpeed), shouldRedact)
    }
}
