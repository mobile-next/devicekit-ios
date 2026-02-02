/// Errors that can occur during MJPEG streaming.
enum MJPEGFrameError: Error, LocalizedError {
    case screenshotFailed

    var errorDescription: String? {
        switch self {
        case .screenshotFailed:
            return "Failed to capture screenshot"
        }
    }
}

/// Produces MJPEG-encoded frames from device screenshots, applying optional
/// scaling and pacing output to a target frame interval.
///
/// `FrameProducer` encapsulates the full lifecycle of generating a single
/// multipart MJPEG frame:
///   - capturing a screenshot via the XCTest daemon (JPEG-compressed at source)
///   - optionally scaling the JPEG to reduce resolution
///   - wrapping the JPEG in a multipart MJPEG boundary with appropriate headers
///   - recording detailed timing and size metrics
///   - enforcing a frame interval by sleeping for the remaining budget
///
/// This type is designed to be used by higher-level MJPEG streaming components
/// that repeatedly call `captureFrame(...)` to produce a continuous stream.
///
/// The class is intentionally lightweight and stateless aside from metrics
/// tracking and frame counting.
final class MJPEGFrameProducer {

    // MARK: - Configuration Constants

    /// MJPEG boundary string used to delimit frames in a multipart response.
    ///
    /// This boundary is written before each JPEG payload and must match the
    /// boundary declared in the HTTP `Content-Type` header of the MJPEG stream.
    private let boundary = "mjpeg-frame-boundary"

    /// Maximum allowed time for screenshot capture before the operation is
    /// considered failed.
    ///
    /// The screenshot daemon is not real‑time and may stall under load; this
    /// timeout prevents the pipeline from blocking indefinitely.
    private let captureTimeout: TimeInterval = 0.5

    /// Number of frames between periodic metrics summary logs.
    ///
    /// This helps avoid excessive logging while still providing insight into
    /// capture performance over time.
    private let metricsReportInterval: UInt64 = 30

    // MARK: - Dependencies

    /// Component responsible for scaling JPEG data while preserving quality.
    ///
    /// Scaling is performed only when the requested scale factor is less than 1.0.
    private let imageScaler: MJPEGImageScaler

    /// Metrics collector used to record capture time, scaling time, output size,
    /// and periodic summary logs.
    private let metrics: MJPEGMetrics

    private let frameInterval: UInt64

    // MARK: - State

    /// Total number of frames produced since initialization.
    ///
    /// Used to determine when to emit periodic metrics summaries.
    private var frameCount: UInt64 = 0

    // MARK: - Initialization

    /// Creates a new frame producer with the given scaler and metrics collector.
    ///
    /// - Parameters:
    ///   - imageScaler: JPEG scaling utility.
    ///   - metrics: Metrics recorder for capture and output performance.
    init(imageScaler: MJPEGImageScaler, metrics: MJPEGMetrics, frameInterval: UInt64) {
        self.imageScaler = imageScaler
        self.metrics = metrics
        self.frameInterval = frameInterval
    }

    // MARK: - Frame Capture

    /// Captures a single MJPEG frame, optionally scales it, wraps it in a
    /// multipart boundary, records metrics, and enforces a frame interval.
    ///
    /// This method must run on the main actor because screenshot capture via
    /// XCTest daemon APIs is main‑thread‑affine.
    ///
    /// - Parameters:
    ///   - quality: JPEG compression quality in the range `[0.0, 1.0]`.
    ///   - scale: Optional downscale factor. Values < 1.0 reduce resolution.
    ///   - frameInterval: Target frame duration in nanoseconds. The method will
    ///     sleep for the remaining time if capture and processing complete early.
    ///
    /// - Returns: A `Data` object containing the full multipart MJPEG frame,
    ///   including boundary, headers, and JPEG payload.
    ///
    /// - Throws: `MJPEGError.screenshotFailed` if screenshot capture fails or
    ///   times out.
    @MainActor
    func captureFrame(
        quality: Double,
        scale: CGFloat
    ) async throws -> Data {

        let startTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)

        // Capture screenshot as JPEG via XCTest daemon.
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

        // Apply optional downscaling.
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

        // Construct multipart MJPEG frame.
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

        // Emit periodic metrics summary.
        if frameCount % metricsReportInterval == 0 {
            metrics.logSummary()
        }

        // Enforce frame pacing.
        let elapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - startTime
        if elapsed < frameInterval {
            try await Task.sleep(nanoseconds: frameInterval - elapsed)
        }

        return frameData
    }
}
