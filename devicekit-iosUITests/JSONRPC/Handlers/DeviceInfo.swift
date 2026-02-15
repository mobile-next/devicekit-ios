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
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for device_info method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        do {
            _ = try JSONDecoder().decode(DeviceInfoRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid device_info parameters: \(error.localizedDescription)")
        }

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
