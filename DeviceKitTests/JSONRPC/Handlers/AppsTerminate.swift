import os

struct AppsTerminateRequest : Codable {
    let bundleId: String
    let deviceId: String
}

@MainActor
struct AppsTerminateMethodHandler: RPCMethodHandler {
    static let methodName = "device.apps.terminate"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let request = try decodeParams(AppsTerminateRequest.self, from: params)

        let start = Date()

        logger.info("[Start] Terminating app with bundle ID: \(request.bundleId)")
        XCUIApplication(bundleIdentifier: request.bundleId).terminate()
        logger.info("[Done] Terminating app with bundle ID: \(request.bundleId)")

        let duration = Date().timeIntervalSince(start)
        logger.info("Terminating App duration took \(duration)")
        return .object(["success": .bool(true)])
    }
}

