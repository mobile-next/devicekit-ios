import FlyingFox
import XCTest
import os

/// UI tests for the DeviceKit iOS application.
///
final class devicekit_iosUITests: XCTestCase {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "devicekit_iosUITests"
    )

    private static var swizzledOutIdle = false

    override func setUpWithError() throws {
        // XCTest internals sometimes use XCTAssert* instead of exceptions.
        // Setting `continueAfterFailure` so that the xctest runner does not stop
        // when an XCTest internal error happes (eg: when using .allElementsBoundByIndex
        // on a ReactNative app)
        continueAfterFailure = true
    }

    override class func setUp() {
        logger.trace("setUp")
    }

    @MainActor
    func testRunAutomation() async throws {
        let server = XCTestServer()
        devicekit_iosUITests.logger.info("Will start WebSocket JSON-RPC server")
        try await server.start()
    }

    override class func tearDown() {
        logger.trace("tearDown")
    }
}
