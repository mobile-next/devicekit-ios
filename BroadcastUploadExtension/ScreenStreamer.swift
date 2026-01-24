import CoreImage
import CoreMedia
import H264Codec
import TCP

/// A high‑level component that captures frames, encodes them as H.264,
/// and streams the resulting NAL units over TCP.
///
/// `ScreenStreamer` coordinates two subsystems:
/// - `H264Encoder` — performs hardware‑accelerated H.264 encoding.
/// - `TCPServer` — streams encoded NAL units to a connected client.
///
/// This class does **not** capture frames itself; instead, it exposes `encode(...)`
/// methods that accept `CMSampleBuffer` or `CVImageBuffer` inputs from an external
/// capture pipeline (ReplayKit, AVFoundation, etc.).
///
/// ## Responsibilities
/// - Configure the encoder and TCP server.
/// - Convert screen geometry into encoder dimensions.
/// - Forward encoded NAL units to the TCP server.
/// - Provide simple start/stop lifecycle management.
///
/// ## Important Notes
/// - Only one TCP client is supported at a time (based on `TCPServer` design).
/// - The encoder output is forwarded directly to `tcpServer.dataHandler`.
/// - The encoded stream uses Annex‑B start‑code‑prefixed NAL units.
/// - The encoder session is invalidated on `stop()`, but not recreated automatically.
final class ScreenStreamer {

    /// The underlying H.264 encoder.
    private let h264Encoder: H264Encoder

    /// The TCP server used to stream encoded NAL units.
    private let tcpServer: TCPServer

    /// Creates a new screen streamer with optional dependency injection.
    ///
    /// - Parameters:
    ///   - videoEncoder: A custom or default `H264Encoder`.
    ///   - tcpServer: A custom or default `TCPServer`.
    ///
    /// Dependency injection makes this class testable and allows swapping
    /// encoder/server implementations if needed.
    init(
        videoEncoder: H264Encoder = H264Encoder(),
        tcpServer: TCPServer = TCPServer()
    ) {
        self.h264Encoder = videoEncoder
        self.tcpServer = tcpServer
    }

    /// Starts the TCP server and configures the H.264 encoder.
    ///
    /// - Parameters:
    ///   - port: TCP port to listen on.
    ///   - rect: A rectangle representing the capture region.
    ///   - scaleFactor: Multiplier applied to both width and height of `rect`.
    ///   - qualityFactor: Encoder quality hint (0.0–1.0).
    ///   - expectedFrameRate: Target frame rate for encoding.
    ///   - averageBitRate: Target bitrate in bits per second.
    ///   - isRealTime: Whether to optimize for real‑time encoding.
    ///
    /// ## Behavior
    /// - Starts the TCP server.
    /// - Computes encoder width/height from `rect.scaledDimensions(scaleFactor)`.
    /// - Configures the encoder with the provided parameters.
    /// - Forwards encoded NAL units to the TCP server.
    ///
    /// ## Potential Issues
    /// - If the TCP client disconnects, NAL units may be dropped silently.
    /// - If encoder configuration fails, the TCP server remains running.
    func start(
        port: UInt16,
        rect: CGRect,
        scaleFactor: Float,
        qualityFactor: Float,
        expectedFrameRate: Int,
        averageBitRate: Int,
        isRealTime: Bool
    ) throws {
        try tcpServer.start(port: port)

        let dimensions = rect.scaledDimensions(scaleFactor)
        try h264Encoder.configureCompressSession(
            width: dimensions.width,
            height: dimensions.height,
            isRealTime: isRealTime,
            expectedFrameRate: expectedFrameRate,
            averageBitRate: averageBitRate,
            quality: qualityFactor
        )

        // Forward encoded NAL units to the TCP server.
        h264Encoder.naluHandling = { [weak self] data in
            guard let self else { return }
            tcpServer.dataHandler?(data)
        }
    }

    /// Encodes a `CMSampleBuffer` and forwards the result to the TCP server.
    ///
    /// - Parameters:
    ///   - sampleBuffer: The captured frame.
    ///   - context: The Core Image context used for rotation.
    ///   - orientation: Orientation metadata from ReplayKit or AVFoundation.
    ///
    /// This method delegates to `H264Encoder.encode(...)`.
    func encode(
        sampleBuffer: CMSampleBuffer,
        context: CIContext,
        orientation: CGImagePropertyOrientation
    ) {
        h264Encoder.encode(
            sampleBuffer: sampleBuffer,
            context: context,
            orientation: orientation
        )
    }

    /// Encodes a raw `CVImageBuffer` and forwards the result to the TCP server.
    ///
    /// - Parameters:
    ///   - imageBuffer: The raw pixel buffer.
    ///   - timestamp: Presentation timestamp for the frame.
    ///   - context: The Core Image context used for rotation.
    ///   - orientation: Orientation metadata.
    func encode(
        imageBuffer: CVImageBuffer,
        timestamp: CMTime,
        context: CIContext,
        orientation: CGImagePropertyOrientation
    ) {
        h264Encoder.encode(
            imageBuffer: imageBuffer,
            timestamp: timestamp,
            context: context,
            orientation: orientation
        )
    }

    /// Stops streaming by shutting down the TCP server and invalidating the encoder.
    ///
    /// ## Behavior
    /// - Stops accepting TCP connections.
    /// - Invalidates the encoder session.
    ///
    /// ## Potential Issues
    /// - Does not clear `naluHandling`; if restarted, the closure will be overwritten.
    func stop() {
        tcpServer.stop()
        h264Encoder.invalidateCompressionSession()
    }
}
