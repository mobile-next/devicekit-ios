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
            return .object(["dismissed": .bool(false)])
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
        _ = foregroundApp.perform(NSSelectorFromString("dismissKeyboard"))

        return .object(["dismissed": .bool(true)])
    }
}
