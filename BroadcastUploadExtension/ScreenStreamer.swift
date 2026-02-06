import CoreImage
import CoreMedia
import H264Codec
import OpusCodec
import TCP

final class ScreenStreamer {
    private let h264Encoder: H264Encoder
    private let tcpServer: TCPServer
    private let audioEncoder: OpusAudioEncoder
    private let audioServer: TCPServer

    private var messageBuffer = Data()
    private var isPaused = false
    private var isStopped = false
    private var loggedMissingAudioClient = false

    init(
        videoEncoder: H264Encoder = H264Encoder(),
        tcpServer: TCPServer = TCPServer(),
        audioEncoder: OpusAudioEncoder = OpusAudioEncoder(),
        audioServer: TCPServer = TCPServer()
    ) {
        self.h264Encoder = videoEncoder
        self.tcpServer = tcpServer
        self.audioEncoder = audioEncoder
        self.audioServer = audioServer
    }

    func start(
        port: UInt16,
        rect: CGRect,
        scaleFactor: Float,
        qualityFactor: Float,
        expectedFrameRate: Int,
        averageBitRate: Int,
        isRealTime: Bool,
        audioPort: UInt16?,
        audioBitRate: Int
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

        h264Encoder.naluHandling = { [weak self] data in
            guard let self else { return }
            tcpServer.dataHandler?(data)
        }

        if let audioPort {
            audioEncoder.updateBitRate(audioBitRate)
            try audioServer.start(port: audioPort)
            audioEncoder.opusHandling = { [weak self] data in
                guard let self else { return }
                guard let dataHandler = audioServer.dataHandler else {
                    if !self.loggedMissingAudioClient {
                        self.loggedMissingAudioClient = true
                        NSLog("[ScreenStreamer] Opus frame ready but no audio client connected")
                    }
                    return
                }
                dataHandler(self.lengthPrefixed(data))
            }
        } else {
            audioEncoder.opusHandling = nil
            audioServer.stop()
        }

        tcpServer.messageHandler = { [weak self] data in
            guard let self else { return }
            self.handleIncomingData(data)
        }
    }

    private func handleIncomingData(_ data: Data) {
        messageBuffer.append(data)

        while messageBuffer.count >= 4 {
            let lengthBytes = messageBuffer.prefix(4)
            let length = Int(UInt32(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }))

            guard messageBuffer.count >= 4 + length else { break }

            let messageData = messageBuffer.subdata(in: 4..<(4 + length))
            messageBuffer.removeFirst(4 + length)

            handleJSONRPC(messageData)
        }
    }

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

    private func handleSetConfiguration(params: [String: Any]?) {
        guard let params = params,
              let bitrate = params["bitrate"] as? Int else {
            print("[ScreenStreamer] Invalid params for setConfiguration")
            return
        }

        let frameRate = params["frameRate"] as? Int

        guard bitrate >= 100_000 && bitrate <= 8_000_000 else {
            print("[ScreenStreamer] Bitrate out of range: \(bitrate) (must be 100000-8000000)")
            return
        }

        if let fr = frameRate, (fr < 1 || fr > 60) {
            print("[ScreenStreamer] Frame rate out of range: \(fr) (must be 1-60)")
            return
        }

        do {
            try h264Encoder.updateEncoderSettings(newBitrate: bitrate, newFrameRate: frameRate)
            print("[ScreenStreamer] ✓ Configuration updated: bitrate=\(bitrate) bps" +
                  (frameRate != nil ? ", frameRate=\(frameRate!)" : ""))
        } catch {
            print("[ScreenStreamer] ✗ Failed to update encoder: \(error)")
        }
    }

    private func handlePause() {
        isPaused = true
        print("[ScreenStreamer] ✓ Paused")
    }

    private func handleResume() {
        isPaused = false
        print("[ScreenStreamer] ✓ Resumed")
    }

    private func handleStop() {
        stop()
        print("[ScreenStreamer] ✓ Stopped")
    }

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

    func encodeAudio(sampleBuffer: CMSampleBuffer) {
        guard !isPaused, !isStopped else { return }
        audioEncoder.encode(sampleBuffer: sampleBuffer)
    }

    func stop() {
        isStopped = true
        tcpServer.stop()
        h264Encoder.invalidateCompressionSession()
        audioServer.stop()
        audioEncoder.invalidate()
    }

    private func lengthPrefixed(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        var packet = Data()
        packet.append(Data(bytes: &length, count: MemoryLayout.size(ofValue: length)))
        packet.append(data)
        return packet
    }
}
