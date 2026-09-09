import CoreMedia

extension CMSampleBuffer {
    var isKeyFrame: Bool {
        let attachments = CMSampleBufferGetSampleAttachmentsArray(
            self,
            createIfNecessary: true
        ) as? [[CFString: Any]]

        let isNotKeyFrame = (attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false
        return !isNotKeyFrame
    }
}
