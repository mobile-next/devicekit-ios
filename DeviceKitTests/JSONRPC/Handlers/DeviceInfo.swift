import os

struct DeviceInfoRequest: Codable {
    let deviceId: String
}

@MainActor
struct DeviceInfoMethodHandler: RPCMethodHandler {
    static let methodName = "device.info"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        _ = try decodeParams(DeviceInfoRequest.self, from: params)

        let start = Date()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let frame = springboard.frame
        let scale = Int(UIScreen.main.scale)
        let width = Int(frame.width)
        let height = Int(frame.height)

        let duration = Date().timeIntervalSince(start)
        logger.info("Device info took \(duration), screen: \(width)x\(height)@\(scale)x")

        let screenSize: JSONValue = .object([
            "width": .double(Double(width)),
            "height": .double(Double(height))
        ])
        return .object([
            "screenSize": screenSize,
            "scale": .double(Double(scale))
        ])
    }
}
