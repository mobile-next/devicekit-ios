import Accelerate
import CoreMedia
import VideoToolbox
import UIKit

/// A hardware‑accelerated H.264 encoder built on VideoToolbox.
///
/// `H264Encoder` wraps `VTCompressionSession` to encode `CVImageBuffer` / `CMSampleBuffer`
/// into H.264 NAL units, exposing them via the `naluHandling` callback.
///
/// The encoder:
/// - Configures a `VTCompressionSession` with bitrate, profile, and realtime options.
/// - Extracts SPS/PPS from keyframes and emits them as NAL units with start codes.
/// - Parses encoded frames into NAL units and emits them with Annex‑B start codes.
/// - Supports encoding from both `CMSampleBuffer` and raw `CVImageBuffer`.
///
/// ## Important Notes
/// - The encoder outputs **Annex‑B** formatted NAL units (start‑code prefixed).
/// - Rotation is applied via Core Image (`rotate(context:orientation:)`) before encoding.
/// - The encoder assumes a **Baseline** H.264 profile.
/// - `naluHandling` is invoked on the VideoToolbox callback thread.
/// - `invalidateCompressionSession()` does not clear `session` to `nil`.
public final class H264Encoder: NSObject {

    /// Errors that can occur during encoder configuration.
    enum ConfigurationError: Error {
        /// The compression session could not be created.
        case cannotCreateSession
        /// The compression session properties could not be set.
        case cannotSetProperties
        /// The compression session could not be prepared for encoding.
        case cannotPrepareToEncode
    }

    /// The underlying VideoToolbox compression session.
    private var session: VTCompressionSession?

    /// H.264 NALU start code prefix (Annex‑B format).
    private static let naluStartCode = Data([UInt8](arrayLiteral: 0x00, 0x00, 0x00, 0x01))

    /// Callback invoked for each emitted NAL unit (SPS, PPS, or frame data).
    ///
    /// The data is in **Annex‑B** format: each NAL unit is prefixed with a 4‑byte
    /// start code (`0x00 0x00 0x00 0x01`).
    ///
    /// ## Threading
    /// - This closure is called on the VideoToolbox output callback thread.
    /// - If you touch UI or other main‑thread‑only resources, dispatch accordingly.
    public var naluHandling: ((Data) -> Void)?

    /// Configures and prepares the VideoToolbox compression session.
    ///
    /// - Parameters:
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    ///   - isRealTime: Whether to optimize for real‑time encoding.
    ///   - expectedFrameRate: Expected frame rate (used for keyframe interval and rate control).
    ///   - averageBitRate: Target average bitrate in bits per second.
    ///   - quality: Encoder quality hint (0.0–1.0).
    /// - Throws: `ConfigurationError` if session creation, property setting, or preparation fails.
    ///
    /// ## Behavior
    /// - Creates a `VTCompressionSession` for H.264.
    /// - Sets profile to `Baseline_AutoLevel`.
    /// - Sets keyframe interval to `expectedFrameRate`.
    /// - Enables real‑time mode and power efficiency if requested.
    ///
    /// ## Potential Issues
    /// - No explicit cleanup of an existing session before reconfiguration.
    /// - No validation of `width`, `height`, or bitrate ranges.
    /// - `kVTCompressionPropertyKey_Quality` is a hint; actual quality may vary.
    public func configureCompressSession(
        width: Int32,
        height: Int32,
        isRealTime: Bool,
        expectedFrameRate: Int,
        averageBitRate: Int,
        quality: Float
    ) throws {
        let error = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: kCFAllocatorDefault,
            outputCallback: encodingOutputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard error == errSecSuccess,
              let session = session else {
            throw ConfigurationError.cannotCreateSession
        }

        let propertyDictionary = [
            kVTCompressionPropertyKey_PixelTransferProperties: [
                kVTPixelTransferPropertyKey_ScalingMode: kVTScalingMode_Normal
            ],
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_Baseline_AutoLevel,
            kVTCompressionPropertyKey_MaxKeyFrameInterval: expectedFrameRate,
            kVTCompressionPropertyKey_ExpectedFrameRate: expectedFrameRate,
            kVTCompressionPropertyKey_AverageBitRate: averageBitRate,
            kVTCompressionPropertyKey_RealTime: isRealTime,
            kVTCompressionPropertyKey_MaximizePowerEfficiency: true,
            kVTCompressionPropertyKey_Quality: quality,
        ] as CFDictionary

        guard VTSessionSetProperties(session, propertyDictionary: propertyDictionary) == noErr else {
            throw ConfigurationError.cannotSetProperties
        }

        guard VTCompressionSessionPrepareToEncodeFrames(session) == noErr else {
            throw ConfigurationError.cannotPrepareToEncode
        }

        print("VTCompressSession is ready to use")
    }

    /// Updates the encoder bitrate and optionally frame rate dynamically without restarting the session.
    ///
    /// - Parameters:
    ///   - newBitrate: New target bitrate in bits per second.
    ///   - newFrameRate: Optional new frame rate (nil to keep current).
    ///
    /// This method uses `VTSessionSetProperties` to update the compression session
    /// properties on-the-fly without invalidating and recreating the session.
    ///
    /// ## Important Notes
    /// - Works only if a session is already configured.
    /// - Changes take effect immediately for subsequent frames.
    /// - No SPS/PPS regeneration unless keyframe interval changes.
    ///
    /// ## Potential Issues
    /// - If the session is nil or invalid, throws `cannotSetProperties`.
    public func updateEncoderSettings(newBitrate: Int, newFrameRate: Int? = nil) throws {
        guard let session = session else {
            throw ConfigurationError.cannotSetProperties
        }

        var propertyDict: [CFString: Any] = [
            kVTCompressionPropertyKey_AverageBitRate: newBitrate
        ]

        if let frameRate = newFrameRate {
            propertyDict[kVTCompressionPropertyKey_ExpectedFrameRate] = frameRate
            propertyDict[kVTCompressionPropertyKey_MaxKeyFrameInterval] = frameRate
        }

        let cfDict = propertyDict as CFDictionary
        guard VTSessionSetProperties(session, propertyDictionary: cfDict) == noErr else {
            throw ConfigurationError.cannotSetProperties
        }

        print("[H264Encoder] Updated settings: bitrate=\(newBitrate) bps" +
              (newFrameRate != nil ? ", frameRate=\(newFrameRate!)" : ""))
    }

    /// Invalidates the current compression session and completes pending frames.
    ///
    /// This:
    /// - Completes all pending frames up to `.invalid` timestamp.
    /// - Invalidates the compression session.
    ///
    /// ## Potential Issues
    /// - `session` is not set to `nil` after invalidation; subsequent calls to
    ///   `encode` will still see a non‑nil session reference, which may be invalid.
    public func invalidateCompressionSession() {
        guard let session = session else {
            return
        }

        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        VTCompressionSessionInvalidate(session)
        // Potential improvement: set self.session = nil
    }

    /// VideoToolbox output callback used by the compression session.
    ///
    /// This callback:
    /// - Validates the sample buffer and status.
    /// - Extracts SPS/PPS from keyframes.
    /// - Parses the encoded H.264 bitstream into NAL units.
    /// - Emits each NAL unit via `naluHandling` with a start code prefix.
    ///
    /// ## NALU Parsing
    /// The encoded bitstream uses a length‑prefixed format:
    /// - Each NAL unit starts with a 4‑byte big‑endian length field.
    /// - The callback converts this into Annex‑B by:
    ///   - Reading the length.
    ///   - Extracting the NAL unit bytes.
    ///   - Prefixing with `0x00 0x00 0x00 0x01`.
    ///
    /// ## Potential Issues
    /// - No bounds checking beyond `totalLength`; malformed buffers could cause issues.
    /// - No differentiation between IDR and non‑IDR frames beyond `isKeyFrame`.
    /// - `naluHandling` is optional; if nil, encoded data is effectively dropped.
    private var encodingOutputCallback: VTCompressionOutputCallback = { (
        outputCallbackRefCon: UnsafeMutableRawPointer?,
        _: UnsafeMutableRawPointer?,
        status: OSStatus,
        flags: VTEncodeInfoFlags,
        sampleBuffer: CMSampleBuffer?
    ) in
        guard let sampleBuffer = sampleBuffer else {
            print("nil buffer")
            return
        }
        guard let refcon: UnsafeMutableRawPointer = outputCallbackRefCon else {
            print("nil pointer")
            return
        }
        guard status == noErr else {
            print("encoding failed")
            return
        }
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("CMSampleBuffer is not ready to use")
            return
        }
        guard flags != VTEncodeInfoFlags.frameDropped else {
            print("frame dropped")
            return
        }

        let encoder: H264Encoder = Unmanaged<H264Encoder>.fromOpaque(refcon).takeUnretainedValue()

        // If the encoded frame is a keyframe, extract SPS and PPS.
        if sampleBuffer.isKeyFrame {
            encoder.extractSPSAndPPS(from: sampleBuffer)
        }

        // dataBuffer is a wrapper for the encoded H.264 bitstream.
        var dataBuffer: CMBlockBuffer?
        if #available(iOS 13.0, *) {
            dataBuffer = sampleBuffer.dataBuffer
        } else {
            dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
        }
        guard let dataBuffer = dataBuffer else { return }

        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let error = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )

        guard error == kCMBlockBufferNoErr,
              let dataPointer = dataPointer else { return }

        var packageStartIndex = 0

        while packageStartIndex < totalLength {
            var nextNALULength: UInt32 = 0
            memcpy(&nextNALULength, dataPointer.advanced(by: packageStartIndex), 4)
            nextNALULength = CFSwapInt32BigToHost(nextNALULength)

            let nalu = Data(
                bytes: dataPointer.advanced(by: packageStartIndex + 4),
                count: Int(nextNALULength)
            )

            packageStartIndex += (4 + Int(nextNALULength))

            encoder.naluHandling?(H264Encoder.naluStartCode + nalu)
        }
    }

    /// Extracts SPS and PPS NAL units from a keyframe sample buffer and emits them.
    ///
    /// - Parameter sampleBuffer: A keyframe `CMSampleBuffer` containing H.264 format description.
    ///
    /// This method:
    /// - Reads the `CMVideoFormatDescription` from the sample buffer.
    /// - Queries H.264 parameter sets at indices 0 and 1 (SPS and PPS).
    /// - Wraps them in `Data` and emits them via `naluHandling` with start codes.
    ///
    /// ## Assumptions
    /// - `parameterSetCount == 2` (SPS and PPS only).
    /// - Parameter set indices 0 and 1 correspond to SPS and PPS.
    ///
    /// ## Potential Issues
    /// - If more parameter sets exist (e.g., multiple SPS/PPS), they are ignored.
    /// - No handling for SEI or other parameter NAL units.
    private func extractSPSAndPPS(from sampleBuffer: CMSampleBuffer) {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }

        var parameterSetCount = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            description,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: nil
        )
        guard parameterSetCount == 2 else { return }

        var spsSize: Int = 0
        var sps: UnsafePointer<UInt8>?

        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            description,
            parameterSetIndex: 0,
            parameterSetPointerOut: &sps,
            parameterSetSizeOut: &spsSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )

        var ppsSize: Int = 0
        var pps: UnsafePointer<UInt8>?

        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            description,
            parameterSetIndex: 1,
            parameterSetPointerOut: &pps,
            parameterSetSizeOut: &ppsSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )

        guard let sps = sps,
              let pps = pps else { return }

        [Data(bytes: sps, count: spsSize), Data(bytes: pps, count: ppsSize)].forEach {
            naluHandling?(H264Encoder.naluStartCode + $0)
        }
    }

    /// Encodes a `CMSampleBuffer` after applying rotation via Core Image.
    ///
    /// - Parameters:
    ///   - sampleBuffer: The input sample buffer containing an image buffer.
    ///   - context: The `CIContext` used for rotation rendering.
    ///   - orientation: The orientation to apply before encoding.
    ///
    /// This method:
    /// - Extracts the `CVImageBuffer` from the sample buffer.
    /// - Rotates it using `rotate(context:orientation:)`.
    /// - Encodes the rotated buffer via `VTCompressionSessionEncodeFrame`.
    ///
    /// ## Potential Issues
    /// - If rotation fails, the frame is silently dropped.
    /// - Duration is taken from the sample buffer; if invalid, timing may be off.
    public func encode(
        sampleBuffer: CMSampleBuffer,
        context: CIContext,
        orientation: CGImagePropertyOrientation
    ) {
        guard let session = session,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let rotatedPixelBuffer = imageBuffer.rotate(context: context, orientation: orientation)
        else {
            return
        }

        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)

        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: rotatedPixelBuffer,
            presentationTimeStamp: timeStamp,
            duration: duration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
    }

    /// Encodes a raw `CVImageBuffer` after applying rotation via Core Image.
    ///
    /// - Parameters:
    ///   - imageBuffer: The raw image buffer to encode.
    ///   - timestamp: Presentation timestamp for the encoded frame.
    ///   - context: The `CIContext` used for rotation rendering.
    ///   - orientation: The orientation to apply before encoding.
    ///
    /// This method:
    /// - Rotates the buffer using `rotate(context:orientation:)`.
    /// - Encodes the rotated buffer via `VTCompressionSessionEncodeFrame`.
    ///
    /// ## Potential Issues
    /// - Uses `CMTime.invalid` as duration; some pipelines may expect a valid duration.
    /// - If rotation fails, the frame is silently dropped.
    public func encode(
        imageBuffer: CVImageBuffer,
        timestamp: CMTime,
        context: CIContext,
        orientation: CGImagePropertyOrientation
    ) {
        guard let session = session,
              let rotatedPixelBuffer = imageBuffer.rotate(context: context, orientation: orientation)
        else {
            return
        }

        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: rotatedPixelBuffer,
            presentationTimeStamp: timestamp,
            duration: CMTime.invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
    }
}
