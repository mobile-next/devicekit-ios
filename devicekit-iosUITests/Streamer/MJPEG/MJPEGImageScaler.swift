import UniformTypeIdentifiers

/// Utility for scaling images using Core Graphics.
final class MJPEGImageScaler {

    /// Scales JPEG image data by a given factor.
    ///
    /// - Parameters:
    ///   - data: Original JPEG image data.
    ///   - scaleFactor: Scale factor (0.0-1.0). 0.5 = 50% of original size.
    ///   - quality: JPEG compression quality for output (0.0-1.0).
    /// - Returns: Scaled JPEG data, or nil if scaling failed.
    func scaleJPEG(_ data: Data, scaleFactor: CGFloat, quality: CGFloat) -> Data? {
        guard scaleFactor > 0 && scaleFactor < 1.0 else {
            return data // No scaling needed
        }

        // Create image source from data
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }

        // Calculate new dimensions
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let newWidth = Int(originalWidth * scaleFactor)
        let newHeight = Int(originalHeight * scaleFactor)

        guard newWidth > 0 && newHeight > 0 else {
            return nil
        }

        // Create bitmap context for drawing scaled image
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }

        // Draw scaled image
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        // Get scaled CGImage
        guard let scaledCGImage = context.makeImage() else {
            return nil
        }

        // Encode as JPEG
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, scaledCGImage, options as CFDictionary)
        CGImageDestinationFinalize(destination)

        return mutableData as Data
    }
}

