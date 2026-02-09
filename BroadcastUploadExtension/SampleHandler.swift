import Foundation
import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    private static let defaultPort: UInt16 = 12005
    private static let defaultScaleFactor: Float = 0.5
    private static let defaultQualityFactor: Float = 0.8
    private static let defaultExpectedFrameRate: Int = 30
    private static let defaultAverageBitRate: Int = 8_000_000
    private static let defaultAudioPort: UInt16 = 12006
    private static let defaultAudioBitRate: Int = 64_000

    private static let rpcPort: UInt16 = 12004

    private var context: CIContext?
    private var screenStreamer: ScreenStreamer?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        let port = setupInfo?["port"] as? UInt16 ?? Self.defaultPort
        let usesActualResolution = setupInfo?["usesActualResolution"] as? Bool ?? true
        let rect: CGRect = usesActualResolution ? .actualResolutionScreen : .logicalResolutionScreen
        let scaleFactor = setupInfo?["scaleFactor"] as? Float ?? Self.defaultScaleFactor
        let qualityFactor = setupInfo?["qualityFactor"] as? Float ?? Self.defaultQualityFactor
        let expectedFrameRate = setupInfo?["expectedFrameRate"] as? Int ?? Self.defaultExpectedFrameRate
        let averageBitRate = setupInfo?["averageBitRate"] as? Int ?? Self.defaultAverageBitRate
        let isRealTime = setupInfo?["isRealTime"] as? Bool ?? false
        let audioEnabled = setupInfo?["audioEnabled"] as? Bool ?? true
        let audioPort = setupInfo?["audioPort"] as? UInt16 ?? Self.defaultAudioPort
        let audioBitRate = setupInfo?["audioBitRate"] as? Int ?? Self.defaultAudioBitRate

        context = CIContext()
        screenStreamer = ScreenStreamer()

        do {
            try screenStreamer?.start(
                port: port,
                rect: rect,
                scaleFactor: scaleFactor,
                qualityFactor: qualityFactor,
                expectedFrameRate: expectedFrameRate,
                averageBitRate: averageBitRate,
                isRealTime: isRealTime,
                audioPort: audioEnabled ? audioPort : nil,
                audioBitRate: audioBitRate
            )

            // Double tap will move the app from the foreground
            requestToGoHome()
            requestToGoHome()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private func requestToGoHome() {
        let url = URL(string: "ws://127.0.0.1:\(Self.rpcPort)/rpc")!
        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()

        let request = #"{"jsonrpc":"2.0","method":"io_button","params":{"button":"home","deviceId":""},"id":1}"#
        task.send(.string(request)) { _ in
            task.cancel(with: .normalClosure, reason: nil)
        }
    }

    override func broadcastPaused() {
    }

    override func broadcastResumed() {
    }

    override func broadcastFinished() {
        screenStreamer?.stop()
        context?.clearCaches()
    }

    override func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) {
        switch sampleBufferType {

        case .video:
            guard let context = context else { return }
            guard let orientation = sampleBuffer.orientation else { return }

            screenStreamer?.encode(
                sampleBuffer: sampleBuffer,
                context: context,
                orientation: orientation
            )

        case .audioApp:
            screenStreamer?.encodeAudio(sampleBuffer: sampleBuffer)

        case .audioMic:
            break

        @unknown default:
            fatalError("Unknown type of sample buffer")
        }
    }
}
