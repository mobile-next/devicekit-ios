import AudioToolbox
import CoreMedia
import Foundation

/// Encodes PCM audio sample buffers into Opus frames (48 kHz, mono, 20 ms).
final class OpusAudioEncoder {

    /// Callback invoked for each encoded Opus frame.
    var opusHandling: ((Data) -> Void)?

    private var encoder: OpusEncoderRef?
    private var converter: AudioConverterRef?
    private var inputFormat: AudioStreamBasicDescription?
    private var pendingPCM: [Int16] = []

    private let outputSampleRate: Double = 48_000
    private let outputChannels: UInt32 = 1
    private let frameSize: Int = 960 // 20 ms @ 48 kHz
    private let maxPacketSize: Int = 4000
    private var bitRate: Int

    init(bitRate: Int = 64_000) {
        self.bitRate = bitRate
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        if let encoder {
            OpusEncoderDestroy(encoder)
        }

        encoder = nil
        if let converter {
            AudioConverterDispose(converter)
        }

        converter = nil
        inputFormat = nil
        pendingPCM.removeAll(keepingCapacity: true)
    }

    func updateBitRate(_ newBitRate: Int) {
        bitRate = newBitRate
        if let encoder {
            let status = OpusEncoderSetBitrate(encoder, Int32(bitRate))
            if status != 0 {
                print("[OpusAudioEncoder] Failed to update bitrate: \(status)")
            }
        }
    }

    func encode(sampleBuffer: CMSampleBuffer) {
        guard let pcm = convertToPCM(sampleBuffer: sampleBuffer) else {
            NSLog("[OpusAudioEncoder] PCM conversion returned nil")
            return
        }

        // NSLog("[OpusAudioEncoder] PCM samples: \(pcm.count)")
        pendingPCM.append(contentsOf: pcm)
        encodePendingFrames()
    }

    private func encodePendingFrames() {
        guard let encoder = encoder else {
            return
        }

        while pendingPCM.count >= frameSize {
            let frame = pendingPCM.prefix(frameSize)
            let data = frame.withUnsafeBufferPointer { buffer -> Data? in
                guard let baseAddress = buffer.baseAddress else {
                    return nil
                }

                var output = [UInt8](repeating: 0, count: maxPacketSize)
                let encoded = OpusEncoderEncode(
                    encoder,
                    baseAddress,
                    Int32(frameSize),
                    &output,
                    Int32(maxPacketSize)
                )

                guard encoded > 0 else {
                    NSLog("[OpusAudioEncoder] Opus encode failed: \(encoded)")
                    return nil
                }

                return Data(output.prefix(Int(encoded)))
            }

            if let data {
                NSLog("[OpusAudioEncoder] Opus frame bytes: \(data.count)")
                opusHandling?(data)
            }

            pendingPCM.removeFirst(frameSize)
        }
    }

    private func ensureEncoder() -> Bool {
        if encoder != nil {
            return true
        }

        var error: Int32 = 0
        encoder = OpusEncoderCreate(
            Int32(outputSampleRate),
            Int32(outputChannels),
            Int32(bitRate),
            &error
        )

        if error != 0 {
        NSLog("[OpusAudioEncoder] Failed to create Opus encoder: \(error)")
            encoder = nil
            return false
        }
        return true
    }

    private func convertToPCM(sampleBuffer: CMSampleBuffer) -> [Int16]? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        let inputASBD = asbdPointer.pointee
        NSLog("[OpusAudioEncoder] Input ASBD: rate=\(inputASBD.mSampleRate) channels=\(inputASBD.mChannelsPerFrame) bytesPerFrame=\(inputASBD.mBytesPerFrame) formatFlags=\(inputASBD.mFormatFlags) formatID=\(inputASBD.mFormatID)")
        guard inputASBD.mFormatID == kAudioFormatLinearPCM else {
            NSLog("[OpusAudioEncoder] Input format is not linear PCM")
            return nil
        }

        if !configureConverterIfNeeded(input: inputASBD) {
            return nil
        }

        guard ensureEncoder() else {
            return nil
        }

        var blockBuffer: CMBlockBuffer?
        var requiredSize: Int = 0
        let sizeStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &requiredSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        if sizeStatus != noErr && sizeStatus != kCMSampleBufferError_ArrayTooSmall {
            NSLog("[OpusAudioEncoder] Failed to query AudioBufferList size: \(sizeStatus)")
            return nil
        }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: requiredSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        let bufferListPointer = rawPointer.bindMemory(
            to: AudioBufferList.self,
            capacity: 1
        )

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: bufferListPointer,
            bufferListSize: requiredSize,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            NSLog("[OpusAudioEncoder] CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer failed: \(status)")
            return nil
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)

        let inputFrames = CMSampleBufferGetNumSamples(sampleBuffer)
        if inputFrames <= 0 {
            NSLog("[OpusAudioEncoder] Input sample buffer has no frames")
            return nil
        }

        let ratio = outputSampleRate / Double(inputASBD.mSampleRate)
        let outputFrames = max(1, Int(Double(inputFrames) * ratio))

        var outputPCM = [Int16](repeating: 0, count: outputFrames * Int(outputChannels))
        let outputByteCount = outputPCM.count * MemoryLayout<Int16>.size
        var ioOutputDataPacketSize = UInt32(outputFrames)

        var inputContext = InputContext(
            sourceBufferList: bufferList,
            bytesPerFrame: inputASBD.mBytesPerFrame,
            frameCount: UInt32(inputFrames),
            frameOffset: 0
        )

        let convertStatus = outputPCM.withUnsafeMutableBytes { rawBuffer -> OSStatus in
            guard let baseAddress = rawBuffer.baseAddress else {
                return kAudio_ParamError
            }

            var outBufferList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: outputChannels,
                    mDataByteSize: UInt32(outputByteCount),
                    mData: baseAddress
                )
            )

            return AudioConverterFillComplexBuffer(
                converter!,
                audioConverterInputDataProc,
                &inputContext,
                &ioOutputDataPacketSize,
                &outBufferList,
                nil
            )
        }

        if convertStatus != noErr {
            NSLog("[OpusAudioEncoder] PCM conversion failed: \(convertStatus)")
            return nil
        }

        let producedSamples = Int(ioOutputDataPacketSize) * Int(outputChannels)
        if producedSamples <= 0 {
            NSLog("[OpusAudioEncoder] PCM conversion produced no samples")
            return nil
        }

        outputPCM.removeLast(outputPCM.count - producedSamples)
        return outputPCM
    }

    private func configureConverterIfNeeded(input: AudioStreamBasicDescription) -> Bool {
        if let existing = inputFormat, isSameFormat(existing, input) {
            return true
        }

        if let converter {
            AudioConverterDispose(converter)
        }
        converter = nil
        inputFormat = input

        var output = AudioStreamBasicDescription(
            mSampleRate: outputSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: outputChannels,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        var converterRef: AudioConverterRef?
        var inputASBD = input
        let status = AudioConverterNew(&inputASBD, &output, &converterRef)
        guard status == noErr, let converterRef else {
            NSLog("[OpusAudioEncoder] Failed to create PCM converter: \(status)")
            return false
        }

        var quality = UInt32(kAudioConverterQuality_Medium)
        let qualityStatus = AudioConverterSetProperty(
            converterRef,
            kAudioConverterSampleRateConverterQuality,
            UInt32(MemoryLayout.size(ofValue: quality)),
            &quality
        )
        if qualityStatus != noErr {
            NSLog("[OpusAudioEncoder] Failed to set converter quality: \(qualityStatus)")
        }

        converter = converterRef
        return true
    }

    private func isSameFormat(_ lhs: AudioStreamBasicDescription, _ rhs: AudioStreamBasicDescription) -> Bool {
        lhs.mSampleRate == rhs.mSampleRate &&
        lhs.mFormatID == rhs.mFormatID &&
        lhs.mFormatFlags == rhs.mFormatFlags &&
        lhs.mChannelsPerFrame == rhs.mChannelsPerFrame &&
        lhs.mBitsPerChannel == rhs.mBitsPerChannel &&
        lhs.mBytesPerFrame == rhs.mBytesPerFrame &&
        lhs.mBytesPerPacket == rhs.mBytesPerPacket &&
        lhs.mFramesPerPacket == rhs.mFramesPerPacket
    }

    private struct InputContext {
        var sourceBufferList: UnsafeMutableAudioBufferListPointer
        var bytesPerFrame: UInt32
        var frameCount: UInt32
        var frameOffset: UInt32
    }

    private let audioConverterInputDataProc: AudioConverterComplexInputDataProc = {
        _, ioNumberDataPackets, ioData, _, userData in
        guard let userData else {
            return kAudio_ParamError
        }

        let context = userData.assumingMemoryBound(to: InputContext.self)
        if context.pointee.frameOffset >= context.pointee.frameCount {
            ioNumberDataPackets.pointee = 0
            return noErr
        }

        let framesRemaining = context.pointee.frameCount - context.pointee.frameOffset
        let framesToCopy = min(framesRemaining, ioNumberDataPackets.pointee)
        ioNumberDataPackets.pointee = framesToCopy

        let sourceList = context.pointee.sourceBufferList
        let destList = UnsafeMutableAudioBufferListPointer(ioData)
        destList.count = sourceList.count

        let byteOffset = Int(context.pointee.frameOffset * context.pointee.bytesPerFrame)
        let byteCount = Int(framesToCopy * context.pointee.bytesPerFrame)

        for index in 0..<sourceList.count {
            let source = sourceList[index]
            destList[index].mNumberChannels = source.mNumberChannels
            destList[index].mDataByteSize = UInt32(byteCount)
            destList[index].mData = source.mData?.advanced(by: byteOffset)
        }

        context.pointee.frameOffset += framesToCopy
        return noErr
    }
}
