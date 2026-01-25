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
/// - Handle incoming JSON-RPC control messages.
/// - Provide simple start/stop lifecycle management.
///
/// ## Important Notes
/// - Only one TCP client is supported at a time (based on `TCPServer` design).
/// - The encoder output is forwarded directly to `tcpServer.dataHandler`.
/// - The encoded stream uses Annex‑B start‑code‑prefixed NAL units.
/// - Supports bidirectional communication for encoder configuration updates.
/// - The encoder session is invalidated on `stop()`, but not recreated automatically.
final class ScreenStreamer {

    /// The underlying H.264 encoder.
    private let h264Encoder: H264Encoder

    /// The TCP server used to stream encoded NAL units.
    private let tcpServer: TCPServer

    /// Buffer for assembling partial JSON-RPC messages received over TCP.
    private var messageBuffer = Data()

    /// Whether encoding is paused by a JSON-RPC control message.
    private var isPaused = false

    /// Whether the streamer has been stopped.
    private var isStopped = false

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
        isPaused = false
        isStopped = false

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

        // Handle incoming JSON-RPC messages from the TCP client.
        tcpServer.messageHandler = { [weak self] data in
            guard let self else { return }
            self.handleIncomingData(data)
        }
    }

    /// Handles incoming data from the TCP connection.
    ///
    /// This method assembles length-prefixed JSON-RPC messages from the TCP stream.
    /// Each message has a 4-byte big-endian length prefix followed by JSON payload.
    ///
    /// ## Protocol
    /// - Message format: [4-byte length][JSON payload]
    /// - Length is big-endian uint32
    /// - Messages are distinguished from H.264 NAL units by the first 4 bytes
    ///
    /// ## Important Notes
    /// - Partial messages are buffered in `messageBuffer`
    /// - Multiple messages in a single TCP read are handled correctly
    private func handleIncomingData(_ data: Data) {
        messageBuffer.append(data)

        while messageBuffer.count >= 4 {
            // Read 4-byte length prefix (big-endian)
            let lengthBytes = messageBuffer.prefix(4)
            let length = Int(UInt32(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }))

            // Check if we have the complete message
            guard messageBuffer.count >= 4 + length else { break }

            // Extract message
            let messageData = messageBuffer.subdata(in: 4..<(4 + length))
            messageBuffer.removeFirst(4 + length)

            // Parse and handle JSON-RPC
            handleJSONRPC(messageData)
        }
    }

    /// Parses and handles a JSON-RPC message.
    ///
    /// - Parameter data: The JSON-RPC message data.
    ///
    /// ## Supported Methods
    /// - `screencapture.setConfiguration` - Update encoder bitrate and frame rate
    /// - `screencapture.pause` - Pause encoding
    /// - `screencapture.resume` - Resume encoding
    /// - `screencapture.stop` - Stop streaming and encoder
    private func handleJSONRPC(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String else {
            print("[ScreenStreamer] Invalid JSON-RPC message")
            return
        }

        switch method {
        case "screencapture.setConfiguration":
            handleSetConfiguration(params: json["params"] as? [String: Any])
        case "screencapture.pause":
            handlePause()
        case "screencapture.resume":
            handleResume()
        case "screencapture.stop":
            handleStop()
        default:
            print("[ScreenStreamer] Unknown method: \(method)")
        }
    }

    /// Handles the `screencapture.setConfiguration` method.
    ///
    /// - Parameter params: The method parameters containing bitrate and optional frame rate.
    ///
    /// ## Parameters
    /// - `bitrate` (required): Target bitrate in bits per second (100000 - 8000000)
    /// - `frameRate` (optional): Target frame rate (1 - 60)
    ///
    /// ## Behavior
    /// - Validates parameter ranges
    /// - Updates the H.264 encoder settings dynamically
    /// - Logs success or error
    private func handleSetConfiguration(params: [String: Any]?) {
        guard let params = params,
              let bitrate = params["bitrate"] as? Int else {
            print("[ScreenStreamer] Invalid params for setConfiguration")
            return
        }

        let frameRate = params["frameRate"] as? Int

        // Validate bitrate range: 100 kbps to 8 Mbps
        guard bitrate >= 100_000 && bitrate <= 8_000_000 else {
            print("[ScreenStreamer] Bitrate out of range: \(bitrate) (must be 100000-8000000)")
            return
        }

        // Validate frame rate if provided
        if let fr = frameRate, (fr < 1 || fr > 60) {
            print("[ScreenStreamer] Frame rate out of range: \(fr) (must be 1-60)")
            return
        }

        // Update encoder
        do {
            try h264Encoder.updateEncoderSettings(newBitrate: bitrate, newFrameRate: frameRate)
            print("[ScreenStreamer] ✓ Configuration updated: bitrate=\(bitrate) bps" +
                  (frameRate != nil ? ", frameRate=\(frameRate!)" : ""))
        } catch {
            print("[ScreenStreamer] ✗ Failed to update encoder: \(error)")
        }
    }

    /// Handles the `screencapture.pause` method.
    private func handlePause() {
        isPaused = true
        print("[ScreenStreamer] ✓ Paused")
    }

    /// Handles the `screencapture.resume` method.
    private func handleResume() {
        isPaused = false
        print("[ScreenStreamer] ✓ Resumed")
    }

    /// Handles the `screencapture.stop` method.
    private func handleStop() {
        stop()
        print("[ScreenStreamer] ✓ Stopped")
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
        guard !isPaused, !isStopped else { return }
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
        guard !isPaused, !isStopped else { return }
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
        isStopped = true
        tcpServer.stop()
        h264Encoder.invalidateCompressionSession()
    }
}
