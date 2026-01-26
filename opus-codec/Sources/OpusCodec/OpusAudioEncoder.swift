import AudioToolbox
import CoreMedia
import Foundation
import OpusEncoder

/// Encodes PCM audio sample buffers into Opus frames (48 kHz, mono, 20 ms).
final class OpusAudioEncoder {

    /// Callback invoked for each encoded Opus frame.
    var opusHandling: ((Data) -> Void)?

    private var encoder: OpusEncoderRef?
    private var audioConverter: AudioFormatConverter
    private var pendingPCM: [Int16] = []

    private let outputSampleRate: Double = 48_000
    private let outputChannels: UInt32 = 1
    private let frameSize: Int = 960 // 20 ms @ 48 kHz
    private let maxPacketSize: Int = 4000
    private var bitRate: Int

    init(bitRate: Int = 64_000) {
        self.bitRate = bitRate
        self.audioConverter = AudioFormatConverter(sampleRate: outputSampleRate, channels: outputChannels)
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        if let encoder {
            OpusEncoderDestroy(encoder)
        }

        encoder = nil
        audioConverter.invalidate()
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
        guard ensureEncoder() else {
            return
        }

        guard let pcm = audioConverter.convert(sampleBuffer: sampleBuffer) else {
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
}
