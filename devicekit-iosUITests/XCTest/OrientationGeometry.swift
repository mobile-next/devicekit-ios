import XCTest

// MARK: - Screen Size Helper

/// Utility for determining device screen dimensions with orientation awareness.
///
/// This helper provides accurate screen size information by:
/// - Caching screen dimensions to avoid repeated snapshots
/// - Handling device orientation changes
/// - Falling back to SpringBoard dimensions when app snapshots fail
///
/// ## Usage
/// ```swift
/// // Get physical screen size (portrait dimensions)
/// let (width, height) = OrientationGeometry.physicalScreenSize()
///
/// // Get orientation-aware size
/// let (w, h, orientation) = try OrientationGeometry.actualScreenSize()
///
/// // Transform coordinates for current orientation
/// let adjustedPoint = OrientationGeometry.orientationAwarePoint(
///     width: width,
///     height: height,
///     point: CGPoint(x: 100, y: 200)
/// )
/// ```
struct OrientationGeometry {

    /// Cached screen dimensions to avoid repeated snapshots.
    private static var cachedSize: (Float, Float)?

    /// Bundle ID of the app when cache was last updated.
    private static var lastAppBundleId: String?

    /// Device orientation when cache was last updated.
    private static var lastOrientation: UIDeviceOrientation?

    /// Returns the physical screen size in points.
    ///
    /// This method caches the result and only recalculates when:
    /// - The foreground app changes
    /// - The device orientation changes
    ///
    /// - Returns: A tuple of (width, height) in points.
    static func physicalScreenSize() -> (Float, Float) {
        let springboardBundleId = "com.apple.springboard"

        let app =
            RunningApp.getForegroundApp()
            ?? XCUIApplication(bundleIdentifier: springboardBundleId)

        do {
            let currentAppBundleId = app.bundleID
            let currentOrientation = XCUIDevice.shared.orientation

            if let cached = cachedSize,
                currentAppBundleId == lastAppBundleId,
                currentOrientation == lastOrientation
            {
                NSLog("Returning cached screen size")
                return cached
            }

            let dict = try app.snapshot().dictionaryRepresentation
            let axFrame = AXElement(dict).frame

            // Safely unwrap width/height
            guard let width = axFrame["Width"], let height = axFrame["Height"]
            else {
                NSLog("Frame keys missing, falling back to SpringBoard.")
                let springboard = XCUIApplication(
                    bundleIdentifier: springboardBundleId
                )
                let size = springboard.frame.size
                return (Float(size.width), Float(size.height))
            }

            let screenSize = CGSize(width: width, height: height)
            let size = (Float(screenSize.width), Float(screenSize.height))

            // Cache results
            cachedSize = size
            lastAppBundleId = currentAppBundleId
            lastOrientation = currentOrientation

            return size
        } catch let error {
            NSLog(
                "Failure while getting screen size: \(error), falling back to get springboard size."
            )
            let application = XCUIApplication(
                bundleIdentifier: springboardBundleId
            )
            let screenSize = application.frame.size
            return (Float(screenSize.width), Float(screenSize.height))
        }
    }

    /// Returns the actual device orientation, defaulting to portrait if unknown.
    ///
    /// Works around a known issue where `XCUIDevice.shared.orientation` may
    /// return `.unknown` in certain scenarios.
    ///
    /// - Returns: The current device orientation.
    /// - SeeAlso: https://stackoverflow.com/q/78932288/7009800
    private static func actualOrientation() -> UIDeviceOrientation {
        let orientation = XCUIDevice.shared.orientation
        if orientation == .unknown {
            return UIDeviceOrientation.portrait
        }

        return orientation
    }

    /// Transforms a point to account for device orientation.
    ///
    /// Coordinates provided in portrait orientation are transformed to match
    /// the current device orientation:
    /// - **Portrait**: No transformation
    /// - **Landscape Left**: Point rotated 90° clockwise
    /// - **Landscape Right**: Point rotated 90° counter-clockwise
    ///
    /// - Parameters:
    ///   - width: Screen width in portrait orientation.
    ///   - height: Screen height in portrait orientation.
    ///   - point: The point to transform.
    /// - Returns: The transformed point for the current orientation.
    static func orientationAwarePoint(
        width: Float,
        height: Float,
        point: CGPoint
    ) -> CGPoint {
        let orientation = actualOrientation()

        switch orientation {
        case .portrait:
            return point

        case .landscapeLeft:
            // 90° clockwise
            return CGPoint(
                x: CGFloat(width) - point.y,
                y: point.x
            )

        case .landscapeRight:
            // 90° counter‑clockwise
            return CGPoint(
                x: point.y,
                y: CGFloat(height) - point.x
            )

        case .portraitUpsideDown,
            .faceUp,
            .faceDown,
            .unknown:
            // Treat all of these as portrait
            return point

        @unknown default:
            return point
        }
    }
}
