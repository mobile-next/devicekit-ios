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

        #if os(tvOS)
        // tvOS has no SpringBoard; the main screen bounds describe the full UI.
        let bounds = UIScreen.main.bounds
        let scale = Int(UIScreen.main.scale)
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        #else
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let frame = springboard.frame
        let scale = Int(UIScreen.main.scale)
        let width = Int(frame.width)
        let height = Int(frame.height)
        #endif

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
