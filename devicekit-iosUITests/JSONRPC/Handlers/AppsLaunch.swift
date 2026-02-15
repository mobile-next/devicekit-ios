import os

struct AppsLaunchRequest : Codable {
    let bundleId: String
    let deviceId: String
}

@MainActor
struct ApsLaunchMethodHandler: RPCMethodHandler {
    static let methodName = "device.apps.launch"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for apps_launch method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: AppsLaunchRequest
        do {
            request = try JSONDecoder().decode(AppsLaunchRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid apps_launch parameters: \(error.localizedDescription)")
        }

        let start = Date()

        logger.info("[Start] Launching app with bundle ID: \(request.bundleId)")
        XCUIApplication(bundleIdentifier: request.bundleId).activate()
        logger.info("[Done] Launching app with bundle ID: \(request.bundleId)")

        let duration = Date().timeIntervalSince(start)
        logger.info("Launch App duration took \(duration)")
        return .object(["success": .bool(true)])
    }
}

