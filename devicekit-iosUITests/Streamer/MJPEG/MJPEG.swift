import FlyingFox
import FlyingSocks
import Foundation
import os
import XCTest
import CoreGraphics
import ImageIO

/// Configuration constants for MJPEG streaming.
private enum MJPEGConstants {
    /// Default frames per second for the MJPEG stream.
    static let defaultFPS: Int = 10

    /// Maximum frames per second allowed.
    static let maxFPS: Int = 60

    /// Default JPEG compression quality (0.0 - 1.0).
    static let defaultQuality: CGFloat = 0.25

    /// Minimum JPEG quality allowed.
    static let minQuality: CGFloat = 0.01

    /// Maximum JPEG quality allowed.
    static let maxQuality: CGFloat = 1.0

    /// Default scaling factor (100 = no scaling).
    static let defaultScale: Int = 100

    /// Minimum scaling factor (10%).
    static let minScale: Int = 10

    /// Maximum scaling factor (100%).
    static let maxScale: Int = 100

    /// Server name for HTTP response header.
    static let serverName = "DeviceKit-iOS"
}

/// HTTP handler for MJPEG video streaming endpoint.
///
/// This handler captures screenshots at a configurable frame rate and streams
/// them as MJPEG (Motion JPEG) over HTTP using multipart/x-mixed-replace.
///
/// Uses the fast XCTest daemon proxy for screenshot capture with JPEG
/// compression at the source level for optimal performance.
///
/// ## URL Query Parameters
/// - `fps`: Frame rate (1-60, default: 10)
/// - `quality`: JPEG quality (1-100, default: 25)
/// - `scale`: Image scale (10-100, default: 100 = no scaling)
///
/// ## Example Usage
/// ```bash
/// # Stream with default settings (10 fps, 25% quality, full resolution)
/// curl http://127.0.0.1:12004/mjpeg --output stream.mjpeg
///
/// # Stream with higher FPS and quality
/// curl "http://127.0.0.1:12004/mjpeg?fps=30&quality=50" --output stream.mjpeg
///
/// # Stream with reduced resolution for lower bandwidth
/// curl "http://127.0.0.1:12004/mjpeg?fps=15&quality=30&scale=50" --output stream.mjpeg
///
/// # View in VLC or browser
/// vlc http://127.0.0.1:12004/mjpeg
/// # Or open in browser: http://127.0.0.1:12004/mjpeg
/// ```
@MainActor
struct MJPEGHTTPHandler: HTTPHandler {
    private let boundary = "mjpeg-frame-boundary"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "MJPEGStream"
    )

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Parse query parameters
        let fps = parseQueryInt(from: request, name: "fps", default: MJPEGConstants.defaultFPS, min: 1, max: MJPEGConstants.maxFPS)
        let qualityPercent = parseQueryInt(from: request, name: "quality", default: 25, min: 1, max: 100)
        let scalePercent = parseQueryInt(from: request, name: "scale", default: MJPEGConstants.defaultScale, min: MJPEGConstants.minScale, max: MJPEGConstants.maxScale)

        let quality = max(MJPEGConstants.minQuality, min(MJPEGConstants.maxQuality, CGFloat(qualityPercent) / 100.0))
        let scale = CGFloat(scalePercent) / 100.0

        logger.info("Starting MJPEG stream: fps=\(fps), quality=\(qualityPercent)%, scale=\(scalePercent)%")

        // Create the MJPEG stream
        let stream = MJPEGByteStream(fps: fps, quality: quality, scale: scale)
        let bodySequence = HTTPBodySequence(from: stream)

        // Build response with multipart headers
        var headers: [HTTPHeader: String] = [:]
        headers[.contentType] = "multipart/x-mixed-replace; boundary=\(boundary)"
        headers[HTTPHeader("Server")] = MJPEGConstants.serverName
        headers[HTTPHeader("Connection")] = "close"
        headers[HTTPHeader("Cache-Control")] = "no-cache, no-store, must-revalidate"
        headers[HTTPHeader("Pragma")] = "no-cache"
        headers[HTTPHeader("Expires")] = "0"

        return HTTPResponse(
            statusCode: .ok,
            headers: headers,
            body: bodySequence
        )
    }

    private func parseQueryInt(from request: HTTPRequest, name: String, default defaultValue: Int, min minValue: Int, max maxValue: Int) -> Int {
        guard let param = request.query.first(where: { $0.name == name }),
              let intValue = Int(param.value) else {
            return defaultValue
        }
        return Swift.max(minValue, Swift.min(maxValue, intValue))
    }
}

/// Async byte sequence that produces MJPEG frame data.
///
/// Conforms to `AsyncBufferedSequence<UInt8>` for integration with FlyingFox's
/// `HTTPBodySequence`. Each buffer yields a complete MJPEG frame including
/// the multipart boundary, headers, and JPEG image data.
struct MJPEGByteStream: AsyncBufferedSequence, Sendable {
    typealias Element = UInt8

    let fps: Int
    let quality: CGFloat
    let scale: CGFloat

    init(fps: Int, quality: CGFloat, scale: CGFloat = 1.0) {
        self.fps = fps
        self.quality = quality
        self.scale = scale
    }

    func makeAsyncIterator() -> MJPEGByteIterator {
        MJPEGByteIterator(fps: fps, quality: quality, scale: scale)
    }
}

/// Iterator that captures screenshots using the fast daemon proxy and yields MJPEG frame bytes.
final class MJPEGByteIterator: AsyncBufferedIteratorProtocol, @unchecked Sendable {
    private let fps: Int
    private let quality: CGFloat
    private let scale: CGFloat

    private let frameProducer: MJPEGFrameProducer
    private let metrics: MJPEGMetrics

    private var isCancelled: Bool = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "devicekit-ios",
        category: "MJPEGIterator"
    )

    init(fps: Int, quality: CGFloat, scale: CGFloat) {
        self.fps = fps
        self.quality = quality
        self.scale = scale

        self.metrics = MJPEGMetrics(targetFPS: fps)
        self.frameProducer = MJPEGFrameProducer(imageScaler: MJPEGImageScaler(), metrics: self.metrics, frameInterval: UInt64(1_000_000_000 / max(1, fps)))
    }

    func next() async throws -> UInt8? {
        guard !isCancelled, !Task.isCancelled else { return nil }
        let buffer = try await nextBuffer(suggested: 1)
        return buffer?.first
    }

    func nextBuffer(suggested count: Int) async throws -> [UInt8]? {
        guard !isCancelled else {
            metrics.logSummary()
            return nil
        }

        if Task.isCancelled {
            isCancelled = true
            metrics.logSummary()
            return nil
        }

        do {
            let frameData = try await frameProducer.captureFrame(quality: quality, scale: scale)
            return Array(frameData)
        } catch {
            logger.error("Frame capture error: \(error.localizedDescription)")
            metrics.logSummary()
            isCancelled = true
            return nil
        }
    }

}

