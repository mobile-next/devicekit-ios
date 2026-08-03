import XCTest
import os

#if os(iOS)

struct IOButtonRequest: Codable {
    enum Button: String, Codable {
        case home
        case lock
        case volumeUp
        case volumeDown
    }

    let button: Button
}

@MainActor
struct IOButtonMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.button"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let request = try decodeParams(IOButtonRequest.self, from: params)

        let start = Date()

        logger.info("[Start] Tapping on button: \(request.button.rawValue)")
        switch request.button {
        case .home:
            XCUIDevice.shared.press(.home)
        case .lock:
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        case .volumeUp:
            #if targetEnvironment(simulator)
            logger.warning("volumeUp button is not available on the Simulator")
            #else
            XCUIDevice.shared.press(.volumeUp)
            #endif
        case .volumeDown:
            #if targetEnvironment(simulator)
            logger.warning("volumeDown button is not available on the Simulator")
            #else
            XCUIDevice.shared.press(.volumeDown)
            #endif
        }
        logger.info("[Done] Tapping on button: \(request.button.rawValue)")

        let duration = Date().timeIntervalSince(start)
        logger.info("Button Tap duration took \(duration)")
        return .object(["success": .bool(true)])
    }
}

#elseif os(tvOS)

struct IOButtonRequest: Codable {
    /// tvOS is driven by the Siri Remote. Every button maps to an
    /// `XCUIRemote.Button` press against the currently focused element.
    enum Button: String, Codable {
        case up
        case down
        case left
        case right
        case select
        case menu
        case home
        case playPause
    }

    let button: Button
}

@MainActor
struct IOButtonMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.button"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let request = try decodeParams(IOButtonRequest.self, from: params)

        let start = Date()

        logger.info("[Start] Pressing remote button: \(request.button.rawValue)")
        let remoteButton: XCUIRemote.Button
        switch request.button {
        case .up:
            remoteButton = .up
        case .down:
            remoteButton = .down
        case .left:
            remoteButton = .left
        case .right:
            remoteButton = .right
        case .select:
            remoteButton = .select
        case .menu:
            remoteButton = .menu
        case .home:
            remoteButton = .home
        case .playPause:
            remoteButton = .playPause
        }
        XCUIRemote.shared.press(remoteButton)
        logger.info("[Done] Pressing remote button: \(request.button.rawValue)")

        let duration = Date().timeIntervalSince(start)
        logger.info("Remote button press duration took \(duration)")
        return .object(["success": .bool(true)])
    }
}

#endif
