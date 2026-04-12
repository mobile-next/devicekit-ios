import os

@MainActor
struct AppsForegroundMethodHandler: RPCMethodHandler {
    static let methodName = "device.apps.foreground"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let start = Date()

        logger.info("[Start] Getting foreground app")

        let foregroundApp = RunningApp.getForegroundApp()
        guard let foregroundApp = foregroundApp else {
            let duration = Date().timeIntervalSince(start)
            logger.info("[Done] No foreground app found, took \(duration)")
            return .object(["bundleId": .string(""), "name": .string(""), "pid": .int(0)])
        }

        guard let bundleId = foregroundApp.bundleID else {
            throw RPCMethodError.internalError("No bundleID in apps_foreground found")
        }

        let name = foregroundApp.label
        let pid = foregroundApp.processID

        let duration = Date().timeIntervalSince(start)
        logger.info("[Done] Foreground app: \(bundleId) (pid: \(pid)), took \(duration)")

        return .object(["bundleId": .string(bundleId), "name": .string(name), "pid": .int(Int(pid))])
    }
}
