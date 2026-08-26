import Foundation
import Network
import os

private enum Constants {
    static let hostAppBundleId = "com.mobilenext.devicekit-ios"
    static let controlHost = "127.0.0.1"
    static let controlPort: UInt16 = 12005
    static let controlTimeout: TimeInterval = 3
}

@MainActor
struct H264StartMethodHandler: RPCMethodHandler {
    static let methodName = "device.h264.start"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let app = XCUIApplication(bundleIdentifier: Constants.hostAppBundleId)

        if app.running {
            logger.info("Terminating host app so it relaunches and re-triggers the picker")
            app.terminate()
        }

        logger.info("Launching host app to trigger the broadcast picker")
        app.activate()

        try await Self.confirmBroadcastStart()

        try await Task.sleep(nanoseconds: 1_500_000_000)

        for attempt in 1...3 {
            XCUIDevice.shared.press(.home)
            try await Task.sleep(nanoseconds: 500_000_000)

            guard RunningApp.getForegroundApp()?.bundleID == Constants.hostAppBundleId else {
                break
            }
            logger.info("Home press \(attempt) did not leave the host app foregrounded, retrying")
        }

        return .object(["success": .bool(true)])
    }

    // Confirm button label is localized; anchored on our own extension's
    // row instead, whose display name isn't.
    private static func confirmBroadcastStart(timeout: TimeInterval = 5) async throws {
        let springboard = XCUIApplication(bundleIdentifier: RunningApp.springboardBundleId)
        let extensionRow = springboard.buttons["BroadcastUploadExtension"]

        let deadline = Date().addingTimeInterval(timeout)
        while !extensionRow.exists {
            guard Date() < deadline else {
                throw RPCMethodError.internalError("Broadcast picker sheet did not appear within \(timeout)s")
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        let anchorMaxY = extensionRow.frame.maxY
        let confirmButton = springboard.buttons.allElementsBoundByIndex
            .filter { $0.frame.minY > anchorMaxY && $0.frame.minY - anchorMaxY < 150 }
            .min { $0.frame.minY < $1.frame.minY }

        guard let confirmButton else {
            throw RPCMethodError.internalError("Could not locate the Start Broadcast confirmation button")
        }

        confirmButton.tap()
    }
}

@MainActor
struct H264StopMethodHandler: RPCMethodHandler {
    static let methodName = "device.h264.stop"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        do {
            try await H264ControlClient.send(method: "screencapture.stop")
            logger.info("Sent screencapture.stop to the broadcast extension")
            return .object(["success": .bool(true)])
        } catch {
            logger.error("Error stopping broadcast: \(error)")
            throw RPCMethodError.internalError("Error stopping broadcast: \(error.localizedDescription)")
        }
    }
}

// 4-byte big-endian length prefix, then JSON — matches ScreenStreamer's
// control channel on the same TCP port it streams video on.
private enum H264ControlClient {
    enum ControlError: Error {
        case connectionFailed
        case notRunning
    }

    static func send(method: String) async throws {
        let connection = NWConnection(
            host: NWEndpoint.Host(Constants.controlHost),
            port: NWEndpoint.Port(rawValue: Constants.controlPort)!,
            using: .tcp
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false
            let finish: (Result<Void, Error>) -> Void = { result in
                guard !didResume else { return }
                didResume = true
                connection.cancel()
                continuation.resume(with: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let payload = Data("{\"jsonrpc\":\"2.0\",\"method\":\"\(method)\",\"id\":1}".utf8)
                    var length = UInt32(payload.count).bigEndian
                    var message = Data(bytes: &length, count: 4)
                    message.append(payload)
                    connection.send(content: message, completion: .contentProcessed { error in
                        finish(error.map { .failure($0) } ?? .success(()))
                    })
                case .failed, .cancelled:
                    finish(.failure(ControlError.notRunning))
                default:
                    break
                }
            }

            connection.start(queue: .main)

            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.controlTimeout) {
                finish(.failure(ControlError.connectionFailed))
            }
        }
    }
}
