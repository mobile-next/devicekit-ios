import CoreMedia
import ReplayKit

/// Extensions adding convenience accessors for ReplayKit metadata on `CMSampleBuffer`.
///
/// This helper extracts the ReplayKit‑provided video orientation attachment and
/// converts it into a `CGImagePropertyOrientation`. ReplayKit attaches this value
/// when capturing screen or camera content, allowing downstream components
/// (encoders, renderers, processors) to correctly orient frames.
///
/// ## Important Notes
/// - ReplayKit does **not** guarantee that orientation metadata is present.
/// - The attachment value must be convertible to a `uint32Value`.
/// - If the raw value does not map to a valid `CGImagePropertyOrientation`,
///   the initializer will return `nil`.
extension CMSampleBuffer {

    /// Returns the ReplayKit video orientation associated with this sample buffer.
    ///
    /// ReplayKit stores orientation metadata under the key
    /// `RPVideoSampleOrientationKey`. This method retrieves that attachment and
    /// converts it into a `CGImagePropertyOrientation`.
    ///
    /// - Returns: A valid `CGImagePropertyOrientation` if the attachment exists
    ///   and contains a valid raw value; otherwise `nil`.
    ///
    /// ## Potential Issues
    /// - If ReplayKit omits the orientation attachment, this returns `nil`.
    /// - If the attachment contains an unexpected type, the conversion may fail.
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
