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

        let pid = foregroundApp.processID
        // XCUIApplication.label resolves the element, which on an app with a large
        // hierarchy takes seconds; the accessibility server answers for the
        // application element alone in milliseconds.
        let name = AXClientProxy.sharedClient().label(forProcessIdentifier: pid) ?? foregroundApp.label
        let viewController = AXClientProxy.sharedClient().viewControllerClassName(forProcessIdentifier: pid)

        let duration = Date().timeIntervalSince(start)
        logger.info("[Done] Foreground app: \(bundleId) (pid: \(pid)), took \(duration)")

        var result: [String: JSONValue] = [
            "bundleId": .string(bundleId),
            "name": .string(name),
            "pid": .int(Int(pid))
        ]

        if let viewController {
            result["viewController"] = .string(viewController)
        }

        return .object(result)
    }
}
