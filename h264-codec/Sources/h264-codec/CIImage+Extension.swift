import CoreImage

/// Extensions adding orientation‑based flipping utilities to `CIImage`.
///
/// This helper provides a simplified way to remap image orientation using
/// `CGImagePropertyOrientation` values. It does **not** perform a geometric flip
/// (horizontal/vertical mirroring). Instead, it maps orientations to new
/// `CIImageOrientation` values and returns an oriented version of the image.
///
/// ## Important Notes
/// - This method does **not** inspect the image’s existing orientation.
/// - It does **not** apply a true flip transform.
/// - It simply returns a new `CIImage` with a different orientation applied.
/// - Mirrored orientations (`*.Mirrored`) are treated the same as their non‑mirrored counterparts.
/// - If you need an actual pixel‑level flip (horizontal/vertical), you must apply
///   an affine transform instead.
extension CIImage {

    /// Returns a new `CIImage` with orientation adjusted based on the provided
    /// `CGImagePropertyOrientation`.
    ///
    /// - Parameter orientation: The orientation to map from.
    /// - Returns: A new `CIImage` with a remapped orientation.
    ///
    /// ## Behavior
    /// - `.up`, `.upMirrored`, `.down`, `.downMirrored` → `.up`
    /// - `.left`, `.leftMirrored` → `.right`
    /// - `.right`, `.rightMirrored` → `.left`
    ///
    /// ## Potential Issues
    /// - This is not a true flip; it is an orientation remap.
    /// - `.down` and `.downMirrored` collapsing to `.up` may not match expected behavior.
    /// - Mirrored orientations lose their mirrored state.
    /// - If the caller expects EXIF‑accurate orientation handling, this is not sufficient.
    func flip(orientation: CGImagePropertyOrientation) -> CIImage {
        switch orientation {
        case .up, .upMirrored, .down, .downMirrored:
            return oriented(.up)

        case .left, .leftMirrored:
            return oriented(.right)

        case .right, .rightMirrored:
            return oriented(.left)
        }
    }
}
