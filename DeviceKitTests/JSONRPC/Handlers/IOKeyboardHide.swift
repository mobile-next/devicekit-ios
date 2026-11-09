import os

@MainActor
struct IOKeyboardHideMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.keyboard.hide"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let foregroundApp = RunningApp.getForegroundApp() else {
            throw RPCMethodError.internalError("No foreground app found")
        }

        guard foregroundApp.keyboards.firstMatch.exists else {
            return .object(["dismissed": .bool(false)])
        }

        // XCUIApplication has a private `dismissKeyboard` method (see
        // WebDriverAgent's class-dumped private headers). Apple's own XCTest
        // internals use it to resign the keyboard's first responder
        // directly — no synthesized touch or gesture involved, so there's no
        // keyboard-owned gesture (return-key action, swipe-to-type) to
        // misfire. Invoked via the Objective-C runtime, the same way this
        // project's EventRecord already calls other private XCTest APIs.
        let dismissKeyboard = NSSelectorFromString("dismissKeyboard")
        guard foregroundApp.responds(to: dismissKeyboard) else {
            throw RPCMethodError.internalError("dismissKeyboard is not available on this iOS version")
        }
        _ = foregroundApp.perform(dismissKeyboard)

        return .object(["dismissed": .bool(true)])
    }
}
