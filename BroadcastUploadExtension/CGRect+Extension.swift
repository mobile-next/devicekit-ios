import UIKit

/// Convenience extensions for working with screen‑related `CGRect` values.
///
/// This extension provides helpers for:
/// - Getting the screen’s **logical resolution** (`UIScreen.main.bounds`)
/// - Getting the screen’s **actual pixel resolution** (`UIScreen.main.nativeBounds`)
/// - Scaling the longest side of a rectangle by a factor
///
/// ## Important Notes
/// - `logicalResolutionScreen` reflects points, not pixels.
/// - `actualResolutionScreen` reflects physical pixels.
/// - `scaledSide(_:)` always scales the **longest** side of the rectangle.
/// - `nativeSide` ignores orientation; it always returns `max(width, height)`.
extension CGRect {

    /// Returns a rectangle representing the screen’s logical resolution.
    ///
    /// This uses `UIScreen.main.bounds`, which is expressed in **points**.
    static var logicalResolutionScreen: CGRect {
        makeScreen(bounds: UIScreen.main.bounds)
    }

    /// Returns a rectangle representing the screen’s actual pixel resolution.
    ///
    /// This uses `UIScreen.main.nativeBounds`, which is expressed in **pixels**.
    static var actualResolutionScreen: CGRect {
        makeScreen(bounds: UIScreen.main.nativeBounds)
    }

    /// Creates a rectangle with origin at `.zero` and the same size as the given bounds.
    ///
    /// - Parameter bounds: Any rectangle whose width/height should be preserved.
    /// - Returns: A new `CGRect` starting at `.zero` with the same size.
    private static func makeScreen(bounds: CGRect) -> CGRect {
        let size = CGSize(width: bounds.width, height: bounds.height)
        return CGRect(origin: .zero, size: size)
    }

    /// Scales the longest side of the rectangle by the given factor.
    ///
    /// - Parameter factor: A multiplier applied to the rectangle’s longest side.
    /// - Returns: The scaled side as an `Int32`.
    ///
    /// ## Example
    /// If the rectangle is `1920×1080` and factor is `0.5`,
    /// this returns `960`.
    func scaledSide(_ factor: Float) -> Int32 {
        Int32(nativeSide * factor)
    }

    /// The longest side of the rectangle as a `Float`.
    ///
    /// This is orientation‑agnostic: it always returns `max(width, height)`.
    private var nativeSide: Float {
        Float(max(height, width))
    }
}
