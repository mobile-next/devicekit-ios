import os

struct AppsForegroundRequest: Codable {
    let deviceId: String
}

@MainActor
struct AppsForegroundMethodHandler: RPCMethodHandler {
    static let methodName = "device.apps.foreground"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for apps_foreground method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        do {
            _ = try JSONDecoder().decode(AppsForegroundRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid apps_foreground parameters: \(error.localizedDescription)")
        }

        let start = Date()

        logger.info("[Start] Getting foreground app")

        let foregroundApp = RunningApp.getForegroundApp()
        guard let foregroundApp = foregroundApp else {
            let duration = Date().timeIntervalSince(start)
            logger.info("[Done] No foreground app found, took \(duration)")
            return .object(["bundleId": .string(""), "name": .string("")])
        }

        guard let bundleId = foregroundApp.bundleID else {
            throw RPCMethodError.internalError("No bundleID in apps_foreground found")
        }

        let name = foregroundApp.label

        let duration = Date().timeIntervalSince(start)
        logger.info("[Done] Foreground app: \(bundleId), took \(duration)")

        return .object(["bundleId": .string(bundleId), "name": .string(name)])
    }
}
