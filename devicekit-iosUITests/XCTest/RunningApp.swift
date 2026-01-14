import Foundation
import XCTest
import os

// MARK: - Running App

/// Utility for detecting and retrieving the foreground application.
///
/// Provides methods to identify which app is currently in the foreground,
/// falling back to SpringBoard when no app is detected.
///
/// ## Usage
/// ```swift
/// // Get foreground app from a list of bundle IDs
/// let bundleId = RunningApp.getForegroundAppId(["com.example.app1", "com.example.app2"])
///
/// // Get the current foreground XCUIApplication
/// if let app = RunningApp.getForegroundApp() {
///     // Use the app for automation
/// }
/// ```
struct RunningApp {

    /// Bundle identifier for SpringBoard (iOS home screen).
    static let springboardBundleId = "com.apple.springboard"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    private init() {}

    /// Returns the current foreground application.
    ///
    /// Uses XCUIApplication's private `activeAppsInfo()` method to detect
    /// all running applications and returns the one in foreground state.
    ///
    /// - Returns: The foreground `XCUIApplication`, or `nil` if none detected.
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
