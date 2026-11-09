import os

@MainActor
struct DeviceInfoMethodHandler: RPCMethodHandler {
    static let methodName = "device.info"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {

        let start = Date()

        // springboard reports the cover display's frame even when unfolded
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let size = OrientationGeometry.secondaryDisplaySize() ?? springboard.frame.size
        let scale = Int(UIScreen.main.scale)
        let width = Int(size.width)
        let height = Int(size.height)

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
