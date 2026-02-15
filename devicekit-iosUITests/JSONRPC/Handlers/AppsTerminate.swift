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
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for apps_terminate method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: AppsTerminateRequest
        do {
            request = try JSONDecoder().decode(AppsTerminateRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid apps_terminate parameters: \(error.localizedDescription)")
        }

        let start = Date()

        logger.info("[Start] Terminating app with bundle ID: \(request.bundleId)")
        XCUIApplication(bundleIdentifier: request.bundleId).terminate()
        logger.info("[Done] Terminating app with bundle ID: \(request.bundleId)")

        let duration = Date().timeIntervalSince(start)
        logger.info("Terminating App duration took \(duration)")
        return .object(["success": .bool(true)])
    }
}

