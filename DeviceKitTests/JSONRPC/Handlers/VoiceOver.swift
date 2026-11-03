import Foundation
import XCTest

/// Shared plumbing for the device.voiceover.* handlers, which drive XCUIDevice.voiceOverService.
/// The service only exists on iOS 27 and later, on simulators and real devices alike.
@MainActor
enum VoiceOver {
    static let unavailable = RPCMethodError.internalError("VoiceOver control requires iOS 27 or later")

    @available(iOS 27.0, *)
    static var service: XCUIVoiceOverService {
        XCUIDevice.shared.voiceOverService
    }

    /// Reading speech or moving the cursor before enable() fails with a vague "No speech available",
    /// so say what to do instead.
    @available(iOS 27.0, *)
    static func requireEnabled() throws {
        guard service.isEnabled else {
            throw RPCMethodError.internalError("VoiceOver is not enabled, call device.voiceover.set first")
        }
    }

    /// Runs a service call, keeping the service's own message, which already names the cause
    /// (e.g. "moveIn() requires VoiceOver Navigation Style to be set to Groups.").
    static func perform<T>(_ action: String, _ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch {
            throw RPCMethodError.internalError("Failed to \(action): \(error.localizedDescription)")
        }
    }
}
