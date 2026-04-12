import Foundation
import XCTest
import os

struct RunningApp {
    static let springboardBundleId = "com.apple.springboard"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    private init() {}

    static func getForegroundApp() -> XCUIApplication? {
        let runningAppIds = XCUIApplication.activeAppsInfo().compactMap {
            $0["bundleId"] as? String
        }

        NSLog("Detected running apps: \(runningAppIds)")

        if runningAppIds.count == 1, let bundleId = runningAppIds.first {
            return XCUIApplication(bundleIdentifier: bundleId)
        } else {
            return
                runningAppIds
                .map { XCUIApplication(bundleIdentifier: $0) }
                .first { $0.state == .runningForeground }
        }
    }

}
