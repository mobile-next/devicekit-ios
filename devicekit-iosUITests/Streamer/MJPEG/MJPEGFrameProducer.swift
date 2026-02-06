enum MJPEGFrameError: Error, LocalizedError {
    case screenshotFailed

    var errorDescription: String? {
        switch self {
        case .screenshotFailed:
            return "Failed to capture screenshot"
        }
    }
}

final class MJPEGFrameProducer {
    private let boundary = "mjpeg-frame-boundary"
    private let captureTimeout: TimeInterval = 0.5
    private let metricsReportInterval: UInt64 = 30

    private let imageScaler: MJPEGImageScaler
    private let metrics: MJPEGMetrics
    private let frameInterval: UInt64

    private var frameCount: UInt64 = 0

    init(imageScaler: MJPEGImageScaler, metrics: MJPEGMetrics, frameInterval: UInt64) {
        self.imageScaler = imageScaler
        self.metrics = metrics
        self.frameInterval = frameInterval
    }

    @MainActor
    func captureFrame(
        quality: Double,
        scale: CGFloat
    ) async throws -> Data {

        let startTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)

        guard var jpegData = try? FBScreenshot.captureJPEG(
            withQuality: quality,
            timeout: captureTimeout
        ) else {
            metrics.recordCapture(
                durationNs: clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - startTime,
                success: false
            )
            throw MJPEGFrameError.screenshotFailed
        }

        let captureTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        metrics.recordCapture(durationNs: captureTime - startTime, success: true)

        if scale < 1.0 {
            let scaleStart = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
            if let scaledData = imageScaler.scaleJPEG(
                jpegData,
                scaleFactor: scale,
                quality: quality
            ) {
                jpegData = scaledData
                metrics.recordScale(
                    durationNs: clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - scaleStart
                )
            }
        }

        var frameData = Data()
        let header =
            "--\(boundary)\r\n" +
            "Content-Type: image/jpeg\r\n" +
            "Content-Length: \(jpegData.count)\r\n\r\n"

        frameData.append(Data(header.utf8))
        frameData.append(jpegData)
        frameData.append(Data("\r\n".utf8))

        let totalDuration = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - startTime
        metrics.recordFrameOutput(size: frameData.count, totalDurationNs: totalDuration)

        frameCount += 1

        if frameCount % metricsReportInterval == 0 {
            metrics.logSummary()
        }

        let elapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - startTime
        if elapsed < frameInterval {
            try await Task.sleep(nanoseconds: frameInterval - elapsed)
        }

        return frameData
    }
}
