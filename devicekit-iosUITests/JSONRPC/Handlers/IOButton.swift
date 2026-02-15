import os

struct IOButtonRequest : Codable {
    enum Button: String, Codable {
        case home
        case lock
        case volumeUp
        case volumeDown
    }

    let button: Button
    let deviceId: String
}

@MainActor
struct IOButtonMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.button"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for io_button method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: IOButtonRequest
        do {
            request = try JSONDecoder().decode(IOButtonRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid io_button parameters: \(error.localizedDescription)")
        }

        let start = Date()

        logger.info("[Start] Tapping on button: \(request.button.rawValue)")
        switch request.button {
        case .home:
            XCUIDevice.shared.press(.home)
        case .lock:
            XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        case .volumeUp:
            XCUIDevice.shared.press(.volumeUp)
        case .volumeDown:
            XCUIDevice.shared.press(.volumeDown)
        }
        logger.info("[Done] Tapping on button: \(request.button.rawValue)")

        let duration = Date().timeIntervalSince(start)
        logger.info("Button Tap duration took \(duration)")
        return .object(["success": .bool(true)])
    }
}

