import ReplayKit

/// A ReplayKit broadcast handler that captures screen frames, encodes them as H.264,
/// and streams them over TCP using `ScreenStreamer`.
///
/// `SampleHandler` is the entry point for ReplayKit Broadcast Upload Extensions.
/// ReplayKit delivers video and audio sample buffers to this handler, and the app
/// is responsible for processing or transmitting them.
///
/// ## Responsibilities
/// - Read configuration passed from the host app.
/// - Initialize the Core Image context and `ScreenStreamer`.
/// - Start and stop the streaming pipeline.
/// - Forward video sample buffers to the encoder.
/// - Optionally handle app/mic audio (currently unimplemented).
///
/// ## Important Notes
/// - ReplayKit extensions run in a separate process from the main app.
/// - Crashes inside the extension (e.g., `fatalError`) terminate the broadcast.
/// - The extension must be efficient; heavy work should be avoided on the main thread.
/// - Audio handling is stubbed out and can be implemented if needed.
class SampleHandler: RPBroadcastSampleHandler {

    // MARK: - Default Configuration Constants

    /// Default TCP port for streaming
    private static let defaultPort: UInt16 = 12005

    /// Default scale factor for output resolution (0.5 = half size)
    private static let defaultScaleFactor: Float = 0.5

    /// Default JPEG compression quality (0.0-1.0)
    private static let defaultQualityFactor: Float = 0.8

    /// Default target frame rate in frames per second
    private static let defaultExpectedFrameRate: Int = 30

    /// Default H.264 average bitrate in bits per second
    private static let defaultAverageBitRate: Int = 8_000_000

    // MARK: - Properties

    /// Core Image context used for rotation and pixel buffer processing.
    private var context: CIContext?

    /// High‑level streaming pipeline that encodes frames and sends them over TCP.
    private var screenStreamer: ScreenStreamer?

    /// Called when the broadcast starts.
    ///
    /// ReplayKit provides optional setup info from the host app. This method:
    /// - Extracts configuration values (port, resolution mode, bitrate, etc.).
    /// - Creates a `CIContext` for image processing.
    /// - Creates and configures a `ScreenStreamer`.
    /// - Starts the TCP server and H.264 encoder.
    ///
    /// ## Potential Issues
    /// - Uses `fatalError` on failure, which immediately terminates the broadcast.
    /// - `averageBitRate` default is extremely low (`8`), likely unintended.
    /// - Resolution is square (`rect.scaledSide`), which may not match screen aspect ratio.
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        let port = setupInfo?["port"] as? UInt16 ?? Self.defaultPort
        let usesActualResolution = setupInfo?["usesActualResolution"] as? Bool ?? true
        let rect: CGRect = usesActualResolution ? .actualResolutionScreen : .logicalResolutionScreen
        let scaleFactor = setupInfo?["scaleFactor"] as? Float ?? Self.defaultScaleFactor
        let qualityFactor = setupInfo?["qualityFactor"] as? Float ?? Self.defaultQualityFactor
        let expectedFrameRate = setupInfo?["expectedFrameRate"] as? Int ?? Self.defaultExpectedFrameRate
        let averageBitRate = setupInfo?["averageBitRate"] as? Int ?? Self.defaultAverageBitRate
        let isLetterbox = setupInfo?["isLetterbox"] as? Bool ?? true
        let isRealTime = setupInfo?["isRealTime"] as? Bool ?? false

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
                isLetterbox: isLetterbox,
                isRealTime: isRealTime
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    /// Called when the user pauses the broadcast.
    ///
    /// ReplayKit stops delivering sample buffers until the broadcast is resumed.
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }

    /// Called when the user resumes the broadcast.
    ///
    /// ReplayKit resumes delivering sample buffers.
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }

    /// Called when the broadcast ends.
    ///
    /// This method:
    /// - Stops the streaming pipeline.
    /// - Clears Core Image caches to free GPU memory.
    override func broadcastFinished() {
        screenStreamer?.stop()
        context?.clearCaches()
    }

    /// Processes incoming sample buffers from ReplayKit.
    ///
    /// ReplayKit delivers three types of buffers:
    /// - `.video`: Screen frames (handled here)
    /// - `.audioApp`: App audio (ignored)
    /// - `.audioMic`: Microphone audio (ignored)
    ///
    /// ## Behavior
    /// - For video buffers:
    ///   - Ensures the CI context exists.
    ///   - Extracts orientation metadata from the sample buffer.
    ///   - Forwards the frame to `ScreenStreamer` for encoding and streaming.
    ///
    /// ## Potential Issues
    /// - If orientation metadata is missing, the frame is dropped.
    /// - Audio buffers are ignored; implement if audio streaming is required.
    /// - No error logging for dropped frames.
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
            // Handle app audio if needed.
            break

        case .audioMic:
            // Handle microphone audio if needed.
            break

        @unknown default:
            fatalError("Unknown type of sample buffer")
        }
    }
}
