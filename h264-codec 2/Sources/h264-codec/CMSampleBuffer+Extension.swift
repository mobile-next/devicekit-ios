import CoreMedia
import ReplayKit

extension CMSampleBuffer {
    var isKeyFrame: Bool {
        let attachments =  CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true) as? [[CFString: Any]]
        let isNotKeyFrame = (attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false

        return !isNotKeyFrame
    }

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
