import Foundation
import os

/// Returns what VoiceOver speaks for the element it is focused on, e.g. "Add Favorites, button".
@MainActor
struct VoiceOverSpeechMethodHandler: RPCMethodHandler {
    static let methodName = "device.voiceover.speech"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "devicekit-ios",
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard #available(iOS 27.0, *) else { throw VoiceOver.unavailable }

        try VoiceOver.requireEnabled()
        let output = try VoiceOver.perform("read VoiceOver speech") {
            try VoiceOver.service.currentSpeech()
        }
        let utterance = output.utterance
        logger.info("VoiceOver speech: \(utterance, privacy: .public)")
        return .object(["utterance": .string(utterance)])
    }
}
