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
/// // Create a drag path
/// var dragPath = PointerEventPath.pathForTouch(at: CGPoint(x: 100, y: 500))
/// dragPath.offset += 0.1
/// dragPath.moveTo(point: CGPoint(x: 100, y: 100))
/// dragPath.offset += 0.3
/// dragPath.liftUp()
///
/// // Create a text input path
/// var textPath = PointerEventPath.pathForTextInput()
/// textPath.type(text: "Hello", typingSpeed: 60)
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
    static func pathForTouch(at point: CGPoint, offset: TimeInterval = 0) -> Self {
        let alloced = objc_lookUpClass("XCPointerEventPath")!.alloc() as! NSObject
        let selector = NSSelectorFromString("initForTouchAtPoint:offset:")
        let imp = alloced.method(for: selector)
        typealias Method = @convention(c) (NSObject, Selector, CGPoint, TimeInterval) -> NSObject
        let method = unsafeBitCast(imp, to: Method.self)
        let path = method(alloced, selector, point, offset)
        return Self(path: path, offset: offset)
    }

    /// Creates a path for text input events.
    ///
    /// - Parameter offset: Initial time offset in seconds.
    /// - Returns: A new pointer event path for text input.
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
        typealias Method = @convention(c) (NSObject, Selector, TimeInterval) -> ()
        let method = unsafeBitCast(imp, to: Method.self)
        method(path, selector, offset)
    }

    /// Moves the touch to a new point (drag gesture).
    ///
    /// - Parameter point: The destination point for the drag.
    mutating func moveTo(point: CGPoint) {
        let selector = NSSelectorFromString("moveToPoint:atOffset:")
        let imp = path.method(for: selector)
        typealias Method = @convention(c) (NSObject, Selector, CGPoint, TimeInterval) -> ()
        let method = unsafeBitCast(imp, to: Method.self)
        method(path, selector, point, offset)
    }

    /// Types text using the keyboard.
    ///
    /// - Parameters:
    ///   - text: The text to type.
    ///   - typingSpeed: Characters per second.
    ///   - shouldRedact: Whether to redact the text in logs.
    mutating func type(text: String, typingSpeed: Int, shouldRedact: Bool = false) {
        let selector = NSSelectorFromString("typeText:atOffset:typingSpeed:shouldRedact:")
        let imp = path.method(for: selector)
        typealias Method = @convention(c) (NSObject, Selector, NSString, TimeInterval, UInt64, Bool) -> ()
        let method = unsafeBitCast(imp, to: Method.self)
        method(path, selector, text as NSString, offset, UInt64(typingSpeed), shouldRedact)
    }

    /// Sets keyboard modifier flags (Command, Shift, etc.).
    ///
    /// - Parameter modifiers: The modifier flags to set.
    mutating func set(modifiers: KeyModifierFlags = []) {
        let selector = NSSelectorFromString("setModifiers:mergeWithCurrentModifierFlags:atOffset:")
        let imp = path.method(for: selector)
        typealias Method = @convention(c) (NSObject, Selector, UInt64, Bool, TimeInterval) -> ()
        let method = unsafeBitCast(imp, to: Method.self)
        method(path, selector, modifiers.rawValue, false, offset)
    }
}
