import CoreMedia
import ReplayKit

/// Extensions adding convenience accessors for metadata on `CMSampleBuffer`.
///
/// This extension provides:
/// - `isKeyFrame`: Determines whether the sample buffer represents a keyframe.
/// - `orientation`: Extracts ReplayKit's video orientation attachment.
///
/// ## Important Notes
/// - ReplayKit does not always attach orientation metadata; `orientation` may be `nil`.
/// - `isKeyFrame` relies on sample attachments, which may not exist depending on the encoder.
/// - Using `createIfNecessary: true` will create an empty attachments array if none exists,
///   which may mask missing metadata.
extension CMSampleBuffer {

    /// Indicates whether the sample buffer represents a keyframe.
    ///
    /// This checks the `kCMSampleAttachmentKey_NotSync` attachment:
    /// - If `NotSync == true`, the frame is **not** a keyframe.
    /// - If `NotSync == false` or missing, the frame is treated as a keyframe.
    ///
    /// ## Behavior
    /// - Returns `true` for keyframes.
    /// - Returns `false` for non‑keyframes.
    ///
    /// ## Potential Issues
    /// - Using `createIfNecessary: true` may create an empty attachment array,
    ///   causing the method to incorrectly classify frames as keyframes.
    /// - Some encoders do not populate `NotSync`, so the result may be unreliable.
    var isKeyFrame: Bool {
        let attachments = CMSampleBufferGetSampleAttachmentsArray(
            self,
            createIfNecessary: true
        ) as? [[CFString: Any]]

        let isNotKeyFrame = (attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false
        return !isNotKeyFrame
    }

    /// Returns the ReplayKit video orientation associated with this sample buffer.
    ///
    /// ReplayKit attaches orientation metadata under the key `RPVideoSampleOrientationKey`.
    /// This method extracts that attachment and converts it into a
    /// `CGImagePropertyOrientation` value.
    ///
    /// ## Returns
    /// - A valid `CGImagePropertyOrientation` if the attachment exists.
    /// - `nil` if ReplayKit did not attach orientation metadata.
    ///
    /// ## Potential Issues
    /// - ReplayKit may omit orientation metadata for certain capture configurations.
    /// - The attachment value is expected to be a numeric type convertible to `uint32Value`.
    /// - If the raw value does not map to a valid `CGImagePropertyOrientation`, the result is `nil`.
    var orientation: CGImagePropertyOrientation? {
        guard let sampleOrientation = CMGetAttachment(
            self,
            key: RPVideoSampleOrientationKey as CFString,
            attachmentModeOut: nil
        ) else {
            return nil
        }

        return CGImagePropertyOrientation(rawValue: sampleOrientation.uint32Value)
    }
}
