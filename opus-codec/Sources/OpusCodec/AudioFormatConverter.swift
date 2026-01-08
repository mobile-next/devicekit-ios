import AudioToolbox
import CoreMedia
import Foundation

final class AudioFormatConverter {

    private var converter: AudioConverterRef?
    private var inputFormat: AudioStreamBasicDescription?

    private let outputSampleRate: Double
    private let outputChannels: UInt32

    init(sampleRate: Double, channels: UInt32) {
        self.outputSampleRate = sampleRate
        self.outputChannels = channels
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        if let converter {
            AudioConverterDispose(converter)
        }
        
        converter = nil
        inputFormat = nil
    }

    func convert(sampleBuffer: CMSampleBuffer) -> [Int16]? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        let inputASBD = asbdPointer.pointee
        // NSLog("[AudioFormatConverter] Input ASBD: rate=\(inputASBD.mSampleRate) channels=\(inputASBD.mChannelsPerFrame) bytesPerFrame=\(inputASBD.mBytesPerFrame) formatFlags=\(inputASBD.mFormatFlags) formatID=\(inputASBD.mFormatID)")
        guard inputASBD.mFormatID == kAudioFormatLinearPCM else {
            NSLog("[AudioFormatConverter] Input format is not linear PCM")
            return nil
        }

        if !configureConverterIfNeeded(input: inputASBD) {
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
            NSLog("[AudioFormatConverter] Failed to query AudioBufferList size: \(sizeStatus)")
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
            NSLog("[AudioFormatConverter] CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer failed: \(status)")
            return nil
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)

        let inputFrames = CMSampleBufferGetNumSamples(sampleBuffer)
        if inputFrames <= 0 {
            NSLog("[AudioFormatConverter] Input sample buffer has no frames")
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

        let convertStatus = withUnsafeMutablePointer(to: &inputContext) { contextPtr in
            outputPCM.withUnsafeMutableBytes { rawBuffer -> OSStatus in
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
                    contextPtr,
                    &ioOutputDataPacketSize,
                    &outBufferList,
                    nil
                )
            }
        }

        if convertStatus != noErr {
            NSLog("[AudioFormatConverter] PCM conversion failed: \(convertStatus)")
            return nil
        }

        let producedSamples = Int(ioOutputDataPacketSize) * Int(outputChannels)
        if producedSamples <= 0 {
            NSLog("[AudioFormatConverter] PCM conversion produced no samples")
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
            NSLog("[AudioFormatConverter] Failed to create PCM converter: \(status)")
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
            NSLog("[AudioFormatConverter] Failed to set converter quality: \(qualityStatus)")
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
