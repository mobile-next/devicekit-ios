import Accelerate
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import VideoToolbox

public final class H264Encoder: NSObject {
    enum ConfigurationError: Error {
        case cannotCreateSession
        case cannotSetProperties
        case cannotPrepareToEncode
    }

    private var session: VTCompressionSession?

    private static let naluStartCode = Data([UInt8](arrayLiteral: 0x00, 0x00, 0x00, 0x01))

    public var naluHandling: ((Data) -> Void)?

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

    public func invalidateCompressionSession() {
        guard let session = session else {
            return
        }

        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        VTCompressionSessionInvalidate(session)
    }

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

        if sampleBuffer.isKeyFrame {
            encoder.extractSPSAndPPS(from: sampleBuffer)
        }

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

    public func encode(
        pixelBuffer: CVPixelBuffer,
        timestamp: CMTime
    ) {
        guard let session = session else { return }

        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: CMTime.invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
    }

    public func encode(
        cgImage: CGImage,
        timestamp: CMTime,
        context: CIContext,
        targetSize: CGSize? = nil,
        pool: CVPixelBufferPool? = nil
    ) {
        guard let pixelBuffer = cgImage.toPixelBuffer(
            context: context,
            targetSize: targetSize,
            pool: pool
        ) else {
            return
        }

        encode(pixelBuffer: pixelBuffer, timestamp: timestamp)
    }
}
