import CoreImage
import CoreMedia
import H264Codec
import os

enum H264Error: Error, LocalizedError {
    case captureFailed
    case conversionFailed
    case encoderNotConfigured

    var errorDescription: String? {
        switch self {
        case .captureFailed: return "Screenshot capture failed"
        case .conversionFailed: return "Pixel buffer conversion failed"
        case .encoderNotConfigured: return "Encoder not configured"
        }
    }
}

final class H264FrameProducer: @unchecked Sendable {
    private let captureTimeout: TimeInterval = 0.5

    private var encoder: H264Encoder?
    private var ciContext: CIContext?
    private var pixelBufferPool: CVPixelBufferPool?
    private var targetSize: CGSize?
    private var isConfigured = false
    private var frameCount: UInt64 = 0

    private var continuation: AsyncStream<Data>.Continuation?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "devicekit-ios",
        category: "H264FrameProducer"
    )

    init() {}

    func makeNALUnitStream() -> AsyncStream<Data> {
        AsyncStream { continuation in
            self.continuation = continuation

            continuation.onTermination = { [weak self] _ in
                self?.invalidateEncoder()
            }
        }
    }

    func invalidateEncoder() {
        encoder?.invalidateCompressionSession()
        continuation?.finish()
        continuation = nil
    }

    @MainActor
    func captureAndEncodeFrame(
        fps: Int,
        bitrate: Int,
        quality: Float,
        scale: Float,
        frameInterval: UInt64
    ) async throws {
        let frameStart = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)

        guard let uiImage = try? FBScreenshot.captureUIImage(
            withQuality: 0.9,
            timeout: captureTimeout
        ), let cgImage = uiImage.cgImage else {
            throw H264Error.captureFailed
        }

        if !isConfigured {
            try configureEncoder(
                for: cgImage,
                fps: fps,
                bitrate: bitrate,
                quality: quality,
                scale: scale
            )
        }

        guard let ciContext = ciContext,
              let targetSize = targetSize,
              let encoder = encoder else {
            throw H264Error.encoderNotConfigured
        }

        guard let pixelBuffer = cgImage.toPixelBuffer(
            context: ciContext,
            targetSize: targetSize,
            pool: pixelBufferPool
        ) else {
            throw H264Error.conversionFailed
        }

        let timestamp = CMTime(
            value: CMTimeValue(frameCount),
            timescale: CMTimeScale(fps)
        )
        encoder.encode(pixelBuffer: pixelBuffer, timestamp: timestamp)
        frameCount += 1

        let elapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - frameStart
        if elapsed < frameInterval {
            try await Task.sleep(nanoseconds: frameInterval - elapsed)
        }
    }

    private func configureEncoder(
        for cgImage: CGImage,
        fps: Int,
        bitrate: Int,
        quality: Float,
        scale: Float
    ) throws {
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)

        var scaledWidth = Int(originalWidth * CGFloat(scale))
        var scaledHeight = Int(originalHeight * CGFloat(scale))
        scaledWidth = scaledWidth - (scaledWidth % 2)
        scaledHeight = scaledHeight - (scaledHeight % 2)
        scaledWidth = max(64, scaledWidth)
        scaledHeight = max(64, scaledHeight)

        targetSize = CGSize(width: scaledWidth, height: scaledHeight)

        logger.info("Encoder: \(scaledWidth)x\(scaledHeight) @ \(fps)fps, \(bitrate/1_000_000)Mbps")

        ciContext = CIContext(options: [
            .useSoftwareRenderer: false,
            .highQualityDownsample: false
        ])

        pixelBufferPool = CGImage.createPixelBufferPool(
            size: targetSize!,
            minimumBufferCount: 3
        )

        let enc = H264Encoder()
        try enc.configureCompressSession(H264EncoderConfig(
            width: Int32(scaledWidth),
            height: Int32(scaledHeight),
            isRealTime: true,
            expectedFrameRate: fps,
            averageBitRate: bitrate,
            quality: quality
        ))

        enc.naluHandling = { [weak self] data in
            self?.continuation?.yield(data)
        }

        encoder = enc
        isConfigured = true
    }
}
