import os

@MainActor
struct IOKeyboardStatusMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.keyboard.status"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let foregroundApp = RunningApp.getForegroundApp() else {
            logger.warning("No foreground app found, reporting keyboard as hidden")
            return .object(["visible": .bool(false)])
        }

        let visible = foregroundApp.keyboards.firstMatch.exists
        return .object(["visible": .bool(visible)])
    }
}
