import CoreImage
import CoreMedia

/// Extensions adding rotation utilities to `CVImageBuffer` using Core Image.
///
/// This method converts the pixel buffer into a `CIImage`, applies an orientation
/// transform (via your `flip(orientation:)` helper), and returns a new
/// `CVPixelBuffer` containing the rotated image.
///
/// ## Important Notes
/// - This method does **not** perform a geometric rotation; it applies a CIImage
///   orientation transform.
/// - If the `CIImage` already has a backing pixel buffer (`pixelBuffer`), the
///   method returns it directly without rendering.
/// - If not, a new pixel buffer is allocated and rendered into.
/// - The source buffer is locked `.readOnly` but **not unlocked** if early returns occur.
/// - The pixel format of the output buffer matches the input buffer.
///
/// ## Potential Issues
/// - **Lock/Unlock imbalance**: If `rotatedCIImage.pixelBuffer` exists, the method
///   returns early **without unlocking** the original buffer.
/// - `flip(orientation:)` does not perform a true rotation; it remaps orientation.
/// - `pixelBuffer` on `CIImage` is not guaranteed to exist; relying on it may
///   produce inconsistent behavior.
/// - No color space or attachments are preserved in the new buffer.
/// - No error handling for `CVPixelBufferCreate` beyond nil‑checking.
extension CVImageBuffer {

    /// Rotates the image buffer by applying a Core Image orientation transform.
    ///
    /// - Parameters:
    ///   - context: A `CIContext` used to render the rotated image.
    ///   - orientation: The orientation to apply to the image.
    /// - Returns: A new `CVPixelBuffer` containing the rotated image, or `nil` on failure.
    ///
    /// ## Behavior
    /// 1. Locks the source pixel buffer for read‑only access.
    /// 2. Wraps it in a `CIImage`.
    /// 3. Applies orientation via `flip(orientation:)`.
    /// 4. If the rotated CIImage already has a pixel buffer, returns it directly.
    /// 5. Otherwise, allocates a new pixel buffer and renders into it.
    /// 6. Unlocks the source buffer.
    ///
    /// ## Potential Issues
    /// - **Early return before unlock**: If `rotatedCIImage.pixelBuffer` exists,
    ///   the function returns without calling `CVPixelBufferUnlockBaseAddress`.
    /// - The output buffer inherits only width, height, and pixel format — not
    ///   attachments, color space, or metadata.
    func rotate(context: CIContext, orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(self, .readOnly)

        let ciImage = CIImage(cvPixelBuffer: self)
        let rotatedCIImage = ciImage.flip(orientation: orientation)

        // ⚠️ Potential bug:
        // Early return without unlocking the base address.
        if let rotatedPixelBuffer = rotatedCIImage.pixelBuffer {
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
            return rotatedPixelBuffer
        }

        var rotatedPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(rotatedCIImage.extent.width),
            Int(rotatedCIImage.extent.height),
            CVPixelBufferGetPixelFormatType(self),
            nil,
            &rotatedPixelBuffer
        )

        guard let rotatedBuffer = rotatedPixelBuffer else {
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
            return nil
        }

        context.render(rotatedCIImage, to: rotatedBuffer)

        CVPixelBufferUnlockBaseAddress(self, .readOnly)

        return rotatedBuffer
    }
}
