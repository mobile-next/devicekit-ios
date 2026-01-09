import XCTest

/// Default timeout used when waiting for UI elements to appear.
private let defaultExistenceTimeout: TimeInterval = 5

/// Convenience helpers for interacting with system alerts in UI tests.
extension XCUIApplication {

    /// Closes the “Broadcast Failed” alert if it appears.
    ///
    /// This method:
    /// - Waits up to `defaultExistenceTimeout` seconds for an “OK” button.
    /// - Checks that the button is hittable.
    /// - Taps it to dismiss the alert.
    ///
    /// ## Potential Issues
    /// - Relies on the button being labeled exactly `"OK"`.
    /// - If the alert appears with a different identifier, it will not be dismissed.
    /// - If the alert appears after this method is called, it will not be handled.
    fileprivate func closeBroadcastFailedAlertIfNeeded() {
        let okButton = buttons["OK"]
        let okButtonExists = okButton.waitForExistence(timeout: defaultExistenceTimeout)
        if okButtonExists && okButton.isHittable {
            okButton.tap()
        }
    }
}

/// UI tests for the DeviceKit iOS application.
///
/// These tests automate the ReplayKit broadcast flow by interacting with
/// SpringBoard and the app under test. The goal is to ensure that:
/// - The app launches correctly.
/// - The broadcast extension can be selected.
/// - The broadcast can be started.
/// - Any system alerts are dismissed automatically.
///
/// ## Important Notes
/// - These tests rely heavily on SpringBoard identifiers, which may change across iOS versions.
/// - UI tests involving ReplayKit are inherently fragile due to system UI timing.
/// - `sleep(3)` is used as a stabilization delay; replacing it with expectations would be more robust.
final class devicekit_iosUITests: XCTestCase {

    /// Called before each test method.
    ///
    /// This method:
    /// - Disables continuation after failure.
    /// - Leaves room for additional environment setup if needed.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Called after each test method.
    ///
    /// Currently unused, but available for cleanup logic.
    override func tearDownWithError() throws {}

    /// Tests the full ReplayKit broadcast start flow.
    ///
    /// Steps:
    /// 1. Interact with SpringBoard to dismiss any broadcast failure alerts.
    /// 2. Ensure the app is running in the foreground.
    /// 3. Tap the broadcast extension selector if needed.
    /// 4. Tap “Start Broadcast”.
    /// 5. Wait briefly for the broadcast to initialize.
    /// 6. Return to the home screen.
    ///
    /// ## Potential Issues
    /// - Uses hard‑coded button identifiers (`"BroadcastUploadExtension"`, `"Start Broadcast"`, `"Stop Broadcast"`).
    /// - Uses `sleep(3)` instead of proper XCTest expectations.
    /// - Relies on SpringBoard UI structure, which may differ across devices or OS versions.
    /// - `recorderApp.tap()` may not always bring the app to the foreground reliably.
    @MainActor
    func testStartStreaming() throws {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.closeBroadcastFailedAlertIfNeeded()

        let recorderApp = XCUIApplication()
        if recorderApp.state != .runningForeground {
            recorderApp.activate()
            springboard.closeBroadcastFailedAlertIfNeeded()
        }

        XCTAssertEqual(
            recorderApp.state,
            .runningForeground,
            "the app is not running in foreground, state: \(recorderApp.state)"
        )

        let selectBroadcastButton = springboard.buttons["BroadcastUploadExtension"]
        let startBroadcastButton = springboard.buttons["Start Broadcast"]
        let stopBroadcastButton = springboard.buttons["Stop Broadcast"]

        recorderApp.tap()

        // If a broadcast is already running, stop early.
        if stopBroadcastButton.waitForExistence(timeout: defaultExistenceTimeout) {
            returnToHomeScreen()
            return
        }

        // Select the broadcast extension if needed.
        if selectBroadcastButton.waitForExistence(timeout: defaultExistenceTimeout),
           selectBroadcastButton.isHittable {
            selectBroadcastButton.tap()
        }

        // If the start button is not visible, tap the popup container.
        if !startBroadcastButton.waitForExistence(timeout: defaultExistenceTimeout) {
            recorderApp.otherElements["start_broadcast_popup"].tap()
        }

        startBroadcastButton.tap()

        // Allow time for the broadcast to initialize. It takes exactly 3 seconds.
        sleep(3)

        returnToHomeScreen()
        springboard.closeBroadcastFailedAlertIfNeeded()
    }

    /// Measures the application launch performance.
    ///
    /// This test uses `XCTApplicationLaunchMetric` to measure how long it takes
    /// for the app to launch from a cold state.
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    /// Returns to the iOS home screen by simulating three Home button presses.
    ///
    /// ## Notes
    /// - On devices without a physical Home button, this simulates the gesture.
    /// - Pressing three times ensures the test exits nested UI states.
    private func returnToHomeScreen() {
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.press(.home)
    }
}
