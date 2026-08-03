import XCTest
import os

/// UI tests for the DeviceKit iOS application.
///
final class DeviceKitUITests: XCTestCase {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "DeviceKitUITests"
    )

    override func setUpWithError() throws {
        continueAfterFailure = true

        // WDA PR #664 (FBFailureProofTestCase): prevent the runner from halting
        // when testmanagerd is slow to connect on startup (random ~20s timeout).
        // shouldHaltWhenReceivesControl is a private XCTestCase BOOL property.
        let sel = NSSelectorFromString("setShouldHaltWhenReceivesControl:")
        if responds(to: sel) {
            setValue(NSNumber(value: false), forKey: "shouldHaltWhenReceivesControl")
        }

        // prevent XCTest from resetting shouldHaltWhenReceivesControl back to YES
        let sel2 = NSSelectorFromString("setShouldSetShouldHaltWhenReceivesControl:")
        if responds(to: sel2) {
            setValue(NSNumber(value: false), forKey: "shouldSetShouldHaltWhenReceivesControl")
        }
    }

    // WDA PR #664: swallow XCTest issues instead of propagating them up.
    // The XCTIssue+FBPatcher +load swizzle handles shouldInterruptTest → NO;
    // this override prevents issues from reaching XCTest's failure machinery.
    override func record(_ issue: XCTIssue) {
        Self.logger.warning("XCTest issue (swallowed): \(issue.compactDescription)")
    }

    override class func setUp() {
        logger.trace("setUp")
    }

    @MainActor
    func testRunAutomation() async throws {
        let server = XCTestServer()
        DeviceKitUITests.logger.info("Will start WebSocket JSON-RPC server")
        try await server.start()
    }

    override class func tearDown() {
        logger.trace("tearDown")
    }
}
