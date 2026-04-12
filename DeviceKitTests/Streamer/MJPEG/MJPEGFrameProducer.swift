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

    private let imageScaler: MJPEGImageScaler
    private let frameInterval: UInt64

    init(imageScaler: MJPEGImageScaler, frameInterval: UInt64) {
        self.imageScaler = imageScaler
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
            throw MJPEGFrameError.screenshotFailed
        }

        if scale < 1.0 {
            if let scaledData = imageScaler.scaleJPEG(
                jpegData,
                scaleFactor: scale,
                quality: quality
            ) {
                jpegData = scaledData
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

        let elapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - startTime
        if elapsed < frameInterval {
            try await Task.sleep(nanoseconds: frameInterval - elapsed)
        }

        return frameData
    }
}
