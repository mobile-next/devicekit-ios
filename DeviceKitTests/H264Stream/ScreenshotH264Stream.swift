import Foundation
import CoreImage
import CoreMedia
import CoreVideo
import H264Codec
import TCP
import os
import ImageIO
import Accelerate

/// Configuration for the H.264 screenshot stream.
struct H264StreamConfig {
    /// Target frames per second.
    var fps: Int = 15

    /// Target bitrate in bits per second.
    var bitrate: Int = 2_000_000

    /// JPEG quality for screenshot capture (0.0-1.0).
    var screenshotQuality: Double = 0.5

    /// H.264 encoder quality hint (0.0-1.0).
    var encoderQuality: Float = 0.5

    /// Scale factor (0.1-1.0). 1.0 = full resolution.
    var scale: CGFloat = 1.0

    /// TCP port for streaming.
    var port: UInt16 = 12007
}

/// Streams H.264 encoded video from screenshots over TCP.
///
/// Similar to ScreenStreamer but captures screenshots instead of ReplayKit frames.
/// Simply forwards NAL units to TCP - no caching or duplicate detection.
@MainActor
final class ScreenshotH264Stream {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "devicekit-ios",
        category: "H264Stream"
    )

    private var config = H264StreamConfig()
    private var encoder: H264Encoder?
    private var tcpServer: TCPServer?
    private var ciContext: CIContext?
    private var streamTask: Task<Void, Never>?
    private var frameNumber: Int64 = 0
    private var isRunning = false
    private var pixelBufferPool: CVPixelBufferPool?

    // Cache SPS/PPS/IDR for late-connecting clients
    private var cachedSPS: Data?
    private var cachedPPS: Data?
    private var cachedIDR: Data?

    private let processingQueue = DispatchQueue(
        label: "h264.screenshot.processing",
        qos: .userInitiated
    )

    // Latency tracking
    private var frameStartTime: UInt64 = 0

    /// Starts the H.264 stream.
    func start(config: H264StreamConfig = H264StreamConfig()) throws {
        guard !isRunning else {
            logger.warning("Stream already running")
            return
        }

        self.config = config
        logger.info("Starting H264 stream: \(config.fps)fps, \(config.bitrate)bps, port=\(config.port)")

        // Initialize Core Image context (GPU-backed)
        ciContext = CIContext(options: [.useSoftwareRenderer: false])

        // Initialize encoder
        encoder = H264Encoder()

        let screenSize = getScreenSize()
        let width = Int32(screenSize.width * config.scale)
        let height = Int32(screenSize.height * config.scale)

        logger.info("Encoder dimensions: \(width)x\(height)")

        // Create pixel buffer pool for reuse (avoids allocation per frame)
        let poolAttrs: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 3
        ]
        let pixelBufferAttrs: [CFString: Any] = [
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey: [:],  // IOSurface-backed for GPU
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttrs as CFDictionary,
            pixelBufferAttrs as CFDictionary,
            &pixelBufferPool
        )

        try encoder?.configureCompressSession(H264EncoderConfig(
            width: width,
            height: height,
            isRealTime: true,
            expectedFrameRate: config.fps,
            averageBitRate: config.bitrate,
            quality: config.encoderQuality
        ))

        encoder?.naluHandling = { [weak self] data in
            guard let self else { return }
            tcpServer?.dataHandler?(data)
        }

        // Initialize TCP server
        tcpServer = TCPServer()
        tcpServer?.onClientConnected = { [weak self] in
            guard let self = self else {
                print("[H264Stream] onClientConnected: self is nil")
                return
            }

            print("[H264Stream] Client connected! Sending cached data...")

            guard let handler = self.tcpServer?.dataHandler else {
                print("[H264Stream] ERROR: dataHandler is nil!")
                return
            }

            // Send cached data immediately when client connects
            let sps = self.cachedSPS
            let pps = self.cachedPPS
            let idr = self.cachedIDR

            if let sps = sps {
                print("[H264Stream] Sending cached SPS (\(sps.count) bytes)")
                handler(sps)
            } else {
                print("[H264Stream] WARNING: No cached SPS!")
            }

            if let pps = pps {
                print("[H264Stream] Sending cached PPS (\(pps.count) bytes)")
                handler(pps)
            } else {
                print("[H264Stream] WARNING: No cached PPS!")
            }

            if let idr = idr {
                print("[H264Stream] Sending cached IDR (\(idr.count) bytes)")
                handler(idr)
            } else {
                print("[H264Stream] WARNING: No cached IDR!")
            }
        }
        try tcpServer?.start(port: config.port)

        // Start capture loop
        isRunning = true
        frameNumber = 0
        streamTask = Task { [weak self] in
            await self?.captureLoop()
        }

        logger.info("H264 stream started on port \(config.port)")
    }

    /// Stops the stream.
    func stop() {
        guard isRunning else { return }

        logger.info("Stopping H264 stream")

        isRunning = false
        streamTask?.cancel()
        streamTask = nil

        encoder?.invalidateCompressionSession()
        encoder = nil

        tcpServer?.stop()
        tcpServer = nil

        ciContext = nil
        pixelBufferPool = nil
        cachedSPS = nil
        cachedPPS = nil
        cachedIDR = nil
    }

    /// Updates encoder settings dynamically.
    func updateConfig(bitrate: Int? = nil, fps: Int? = nil) {
        if let bitrate = bitrate {
            config.bitrate = bitrate
        }
        if let fps = fps {
            config.fps = fps
        }

        try? encoder?.updateEncoderSettings(
            newBitrate: config.bitrate,
            newFrameRate: fps
        )
    }

    // MARK: - Private

    private func captureLoop() async {
        let frameInterval = UInt64(1_000_000_000 / max(1, config.fps))

        while !Task.isCancelled && isRunning {
            let startTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)

            await captureAndEncodeFrame()

            // Maintain frame rate
            let elapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - startTime
            if elapsed < frameInterval {
                try? await Task.sleep(nanoseconds: frameInterval - elapsed)
            }
        }
    }

    private func captureAndEncodeFrame() async {
        let t0 = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)

        // 1. Capture stays on MainActor
        guard let uiImage = try? FBScreenshot.captureUIImage(
            withQuality: config.screenshotQuality,
            timeout: 0.5
        ) else {
            logger.error("UIImage capture failed")
            return
        }

        let t1 = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        let captureMs = Double(t1 - t0) / 1_000_000

        // 2. Heavy work off-main
        let config = self.config
        let ciContext = self.ciContext
        let encoder = self.encoder
        let pixelBufferPool = self.pixelBufferPool
        let frameNumber = self.frameNumber

        Task.detached { [logger] in
            let t2 = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)

            guard let scaledImage = UIImageScaler.scaleImage(uiImage, scaleFactor: config.scale),
                  let pixelBuffer = await self.uiImageToPixelBuffer(
                      from: scaledImage,
                      size: scaledImage.size,
                  ) else {
                logger.warning("UIImage to pixel buffer conversion failed")
                return
            }

            let t3 = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
            let convertMs = Double(t3 - t2) / 1_000_000

            guard let ciContext, let encoder else { return }

            let timestamp = CMTime(value: frameNumber, timescale: Int32(config.fps))

            encoder.encode(
                imageBuffer: pixelBuffer,
                timestamp: timestamp,
                context: ciContext,
                orientation: .up
            )

            let t4 = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
            let encodeSubmitMs = Double(t4 - t3) / 1_000_000

            if frameNumber % 30 == 0 {
                logger.info(
                    "Frame \(frameNumber): capture=\(captureMs)ms, convert=\(convertMs)ms, submit=\(encodeSubmitMs)ms"
                )
            }
        }

        // 3. Only frameNumber mutation stays on MainActor
        self.frameNumber += 1
    }


    func uiImageToPixelBuffer(
        from image: UIImage,
        size: CGSize,
    ) -> CVPixelBuffer? {

        guard let cgImage = image.cgImage else { return nil }

        var pixelBuffer: CVPixelBuffer?

        // Reuse from pool if available (much faster!)
        if let pool = pixelBufferPool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        } else {
            let attrs: CFDictionary = [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
            ] as CFDictionary

            CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(size.width),
                Int(size.height),
                kCVPixelFormatType_32BGRA, // Native iOS format
                attrs,
                &pixelBuffer
            )
        }

        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let data = CVPixelBufferGetBaseAddress(buffer) else { return nil }

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        let context = CGContext(
            data: data,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue |
                        CGBitmapInfo.byteOrder32Little.rawValue
        )

        context?.draw(cgImage, in: CGRect(origin: .zero, size: size))

        return buffer
    }


    private func getScreenSize() -> CGSize {
        let screen = UIScreen.main
        return CGSize(
            width: screen.bounds.width * screen.scale,
            height: screen.bounds.height * screen.scale
        )
    }
}
