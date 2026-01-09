import CoreImage
import CoreMedia

extension CVImageBuffer {
    func rotate(context: CIContext, orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(self, .readOnly)

        let ciImage = CIImage(cvPixelBuffer: self)
        let rotatedCIImage = ciImage.flip(orientation: orientation)

        if let rotatedPixelBuffer = rotatedCIImage.pixelBuffer {
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
            return nil
        }
        context.render(rotatedCIImage, to: rotatedBuffer)

        CVPixelBufferUnlockBaseAddress(self, .readOnly)

        return rotatedBuffer
    }
}
