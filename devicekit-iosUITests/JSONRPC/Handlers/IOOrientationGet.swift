import os

struct IOOrientationGetRequest: Codable {
    let deviceId: String
}

@MainActor
struct IOOrientationGetMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.orientation.get"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for io_orientation_get method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        do {
            _ = try JSONDecoder().decode(IOOrientationGetRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid io_orientation_get parameters: \(error.localizedDescription)")
        }

        let start = Date()
        let orientation = XCUIDevice.shared.orientation

        let value: String
        switch orientation {
        case .portrait:
            value = "PORTRAIT"
        case .portraitUpsideDown:
            value = "PORTRAIT"
        case .landscapeLeft:
            value = "LANDSCAPE"
        case .landscapeRight:
            value = "LANDSCAPE"
        default:
            value = "PORTRAIT"
        }

        let duration = Date().timeIntervalSince(start)
        logger.info("Get orientation took \(duration), result: \(value)")
        return .object(["orientation": .string(value)])
    }
}
