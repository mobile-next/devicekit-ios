import CoreMedia
import ReplayKit

extension CMSampleBuffer {
    var orientation: CGImagePropertyOrientation? {
        guard
            let sampleOrientation = CMGetAttachment(
                self,
                key: RPVideoSampleOrientationKey as CFString,
                attachmentModeOut: nil
            )
        else {
            return nil
        }

        return CGImagePropertyOrientation(
            rawValue: sampleOrientation.uint32Value
        )
    }
}
