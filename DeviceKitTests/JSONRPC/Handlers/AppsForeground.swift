import os

/// `viewController` asks for the class name of the view controller on screen. Finding it
/// means snapshotting the hierarchy, which on an app with a large one costs as much as a
/// UI dump, so a caller that only needs to know which app is in front can leave it out.
struct AppsForegroundRequest: Codable {
    let viewController: Bool?
}

@MainActor
struct AppsForegroundMethodHandler: RPCMethodHandler {
    static let methodName = "device.apps.foreground"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let request = try decodeParams(AppsForegroundRequest.self, from: params)
        let includeViewController = request.viewController ?? true
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
        let viewController = includeViewController
            ? AXClientProxy.sharedClient().viewControllerClassName(forProcessIdentifier: pid)
            : nil

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
