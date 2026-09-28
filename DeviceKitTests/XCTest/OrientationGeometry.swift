import XCTest

// maps screen points, as seen in screenshots, onto the touch space of the
// display the foreground app is on
struct OrientationGeometry {
    let portraitWidth: CGFloat
    let portraitHeight: CGFloat
    let orientation: UIDeviceOrientation
    // nil when the app is on the main display
    let displayID: UInt64?

    private static let springboardBundleId = "com.apple.springboard"

    static func current() -> OrientationGeometry {
        let app = RunningApp.getForegroundApp()
            ?? XCUIApplication(bundleIdentifier: springboardBundleId)

        var size = app.frame.size
        if size.width <= 0 || size.height <= 0 {
            NSLog("Foreground app has no frame, falling back to SpringBoard.")
            size = XCUIApplication(bundleIdentifier: springboardBundleId).frame.size
        }

        return OrientationGeometry(
            portraitWidth: min(size.width, size.height),
            portraitHeight: max(size.width, size.height),
            orientation: touchOrientation(of: app),
            displayID: secondaryDisplayID(of: app)
        )
    }

    func touchPoint(for point: CGPoint) -> CGPoint {
        switch orientation {
        case .landscapeLeft:
            return CGPoint(x: portraitWidth - point.y, y: point.x)

        case .landscapeRight:
            return CGPoint(x: point.y, y: portraitHeight - point.x)

        default:
            return point
        }
    }

    // touches follow the app's interface orientation, not the device's: the
    // unfolded iPhone Duo draws its app in landscape while the device reports
    // portrait. UIInterfaceOrientation.landscapeRight shares its raw value with
    // UIDeviceOrientation.landscapeLeft (and vice versa), so the raw value maps
    // straight onto the device orientation touchPoint is written for
    private static func touchOrientation(of app: XCUIApplication) -> UIDeviceOrientation {
        let selector = NSSelectorFromString("interfaceOrientation")
        if app.responds(to: selector),
           let rawValue = app.value(forKey: "interfaceOrientation") as? Int,
           let orientation = UIDeviceOrientation(rawValue: rawValue),
           orientation != .unknown {
            return orientation
        }

        let orientation = XCUIDevice.shared.orientation
        if orientation == .unknown {
            return .portrait
        }
        return orientation
    }

    // foldables show the unfolded app on a secondary display; events without
    // a display id go to the main one and never reach the app. single-display
    // devices skip the snapshot this needs
    static func secondaryDisplayID(of app: XCUIApplication) -> UInt64? {
        guard XCUIScreen.screens.count > 1, let appDisplayID = windowDisplayID(of: app) else {
            return nil
        }

        if appDisplayID == displayID(of: XCUIScreen.main) {
            return nil
        }
        return appDisplayID
    }

    private static func displayID(of screen: XCUIScreen) -> UInt64? {
        guard screen.responds(to: NSSelectorFromString("displayID")) else {
            return nil
        }
        return (screen.value(forKey: "displayID") as? NSNumber)?.uint64Value
    }

    // the application element reports display 0; its windows carry the real
    // display id, so a snapshot two levels deep is enough
    private static func windowDisplayID(of app: XCUIApplication) -> UInt64? {
        let previousMaxDepth = AXClientSwizzler.overwriteDefaultParameters["maxDepth"]
        AXClientSwizzler.overwriteDefaultParameters["maxDepth"] = 2
        defer {
            AXClientSwizzler.overwriteDefaultParameters["maxDepth"] = previousMaxDepth
        }

        guard let root = try? app.snapshot().dictionaryRepresentation else {
            return nil
        }

        let displayKey = XCUIElement.AttributeName(rawValue: "displayID")
        let childrenKey = XCUIElement.AttributeName(rawValue: "children")
        let windows = root[childrenKey] as? [[XCUIElement.AttributeName: Any]] ?? []
        for window in windows {
            if let displayID = window[displayKey] as? Int, displayID != 0 {
                return UInt64(displayID)
            }
        }
        return nil
    }
}
