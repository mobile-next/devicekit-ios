import FlyingFox
import FlyingSocks
import Foundation
import os
import CoreImage
import CoreMedia
import H264Codec

private enum H264Constants {
    static let defaultFPS: Int = 30
    static let maxFPS: Int = 60
    static let defaultBitrate: Int = 4_000_000
    static let minBitrate: Int = 100_000
    static let maxBitrate: Int = 10_000_000
    static let defaultQuality: Int = 60
    static let defaultScale: Int = 50
    static let minScale: Int = 10
    static let maxScale: Int = 100
}

struct H264StreamConfig: Sendable {
    let fps: Int
    let bitrate: Int
    let quality: Float
    let scale: Float
    let frameInterval: UInt64

    init(fps: Int, bitrate: Int, quality: Float, scale: Float) {
        self.fps = fps
        self.bitrate = bitrate
        self.quality = quality
        self.scale = scale
        self.frameInterval = UInt64(1_000_000_000 / max(1, fps))
    }
}

@MainActor
struct H264HTTPHandler: HTTPHandler {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "devicekit-ios",
        category: "H264Stream"
    )

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        let fps = parseQueryInt(from: request, name: "fps", default: H264Constants.defaultFPS, min: 1, max: H264Constants.maxFPS)
        let bitrate = parseQueryInt(from: request, name: "bitrate", default: H264Constants.defaultBitrate, min: H264Constants.minBitrate, max: H264Constants.maxBitrate)
        let quality = Float(parseQueryInt(from: request, name: "quality", default: H264Constants.defaultQuality, min: 1, max: 100)) / 100.0
        let scalePercent = parseQueryInt(from: request, name: "scale", default: H264Constants.defaultScale, min: H264Constants.minScale, max: H264Constants.maxScale)
        let scale = Float(scalePercent) / 100.0

        logger.info("Starting H264 stream: scale=\(scalePercent)% @ \(fps)fps, \(bitrate/1_000_000)Mbps")

        let config = H264StreamConfig(fps: fps, bitrate: bitrate, quality: quality, scale: scale)
        let stream = H264ByteStream(config: config)
        let bodySequence = HTTPBodySequence(from: stream)

        var headers: [HTTPHeader: String] = [:]
        headers[.contentType] = "video/h264"
        headers[HTTPHeader("Server")] = "DeviceKit-iOS"
        headers[HTTPHeader("Connection")] = "close"
        headers[HTTPHeader("Cache-Control")] = "no-cache, no-store, must-revalidate"

        return HTTPResponse(statusCode: .ok, headers: headers, body: bodySequence)
    }

    private func parseQueryInt(from request: HTTPRequest, name: String, default defaultValue: Int, min minValue: Int, max maxValue: Int) -> Int {
        guard let param = request.query.first(where: { $0.name == name }),
              let intValue = Int(param.value) else {
            return defaultValue
        }
        return Swift.max(minValue, Swift.min(maxValue, intValue))
    }
}

struct H264ByteStream: AsyncBufferedSequence, Sendable {
    typealias Element = UInt8

    let config: H264StreamConfig

    func makeAsyncIterator() -> H264ByteIterator {
        H264ByteIterator(config: config)
    }
}

final class H264ByteIterator: AsyncBufferedIteratorProtocol, @unchecked Sendable {
    typealias Element = UInt8
    typealias Buffer = [UInt8]

    private let config: H264StreamConfig
    private let frameProducer: H264FrameProducer
    private let metrics: H264Metrics
    private var naluStream: AsyncStream<Data>?
    private var naluIterator: AsyncStream<Data>.Iterator?
    private var captureTask: Task<Void, Never>?
    private var isCancelled = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "devicekit-ios",
        category: "H264Iterator"
    )

    init(config: H264StreamConfig) {
        self.config = config
        self.metrics = H264Metrics(targetFPS: config.fps, targetBitrate: config.bitrate)
        self.frameProducer = H264FrameProducer(metrics: metrics)

        let stream = frameProducer.makeNALUnitStream()
        self.naluStream = stream
        self.naluIterator = stream.makeAsyncIterator()

        startCaptureLoop()
    }

    deinit {
        captureTask?.cancel()
        frameProducer.invalidateEncoder()
        metrics.logSummary()
    }

    private func startCaptureLoop() {
        captureTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                do {
                    try await self.captureFrame()
                } catch {
                    self.logger.error("Capture error: \(error.localizedDescription)")
                    break
                }
            }
        }
    }

    @MainActor
    private func captureFrame() async throws {
        try await frameProducer.captureAndEncodeFrame(
            fps: config.fps,
            bitrate: config.bitrate,
            quality: config.quality,
            scale: config.scale,
            frameInterval: config.frameInterval
        )
    }

    func next() async throws -> UInt8? {
        guard !isCancelled, !Task.isCancelled else { return nil }
        let buffer = try await nextBuffer(suggested: 1)
        return buffer?.first
    }

    func nextBuffer(suggested count: Int) async throws -> [UInt8]? {
        guard !isCancelled, !Task.isCancelled else {
            metrics.logSummary()
            return nil
        }

        guard let data = await naluIterator?.next() else {
            isCancelled = true
            metrics.logSummary()
            return nil
        }

        return Array(data)
    }
}
