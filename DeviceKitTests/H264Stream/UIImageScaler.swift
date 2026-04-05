import CoreGraphics
import UIKit

/// Utility for scaling UIImages using Core Graphics.
enum UIImageScaler {

    /// Scales a UIImage by a given factor.
    ///
    /// - Parameters:
    ///   - image: Original UIImage.
    ///   - scaleFactor: Scale factor (0.0–1.0). 0.5 = 50% of original size.
    ///   - interpolation: Quality used when scaling (default: .medium).
    /// - Returns: A new scaled UIImage, or nil if scaling failed.
    static func scaleImage(
        _ image: UIImage,
        scaleFactor: CGFloat,
        interpolation: CGInterpolationQuality = .medium
    ) -> UIImage? {

        guard scaleFactor > 0 && scaleFactor < 1 else {
            return image // No scaling needed
        }

        guard let cgImage = image.cgImage else {
            return nil
        }

        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)

        let newWidth = Int(originalWidth * scaleFactor)
        let newHeight = Int(originalHeight * scaleFactor)

        guard newWidth > 0 && newHeight > 0 else {
            return nil
        }

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = interpolation

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let scaledCGImage = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: scaledCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
