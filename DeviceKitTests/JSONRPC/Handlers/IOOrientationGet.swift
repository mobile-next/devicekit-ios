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
        _ = try decodeParams(IOOrientationGetRequest.self, from: params)

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
