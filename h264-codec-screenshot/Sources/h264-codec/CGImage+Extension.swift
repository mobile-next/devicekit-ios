import CoreGraphics
import CoreImage
import CoreVideo

extension CGImage {
    public func toPixelBuffer(
        context: CIContext,
        targetSize: CGSize? = nil,
        pixelFormat: OSType = kCVPixelFormatType_32BGRA,
        pool: CVPixelBufferPool? = nil
    ) -> CVPixelBuffer? {
        var ciImage = CIImage(cgImage: self)

        let outputSize = targetSize ?? CGSize(width: width, height: height)

        let scaleX = outputSize.width / ciImage.extent.width
        let scaleY = outputSize.height / ciImage.extent.height
        if abs(scaleX - 1.0) > 0.001 || abs(scaleY - 1.0) > 0.001 {
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }

        var pixelBuffer: CVPixelBuffer?

        if let pool = pool {
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            if status != kCVReturnSuccess {
                return nil
            }
        } else {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
                kCVPixelBufferWidthKey as String: Int(outputSize.width),
                kCVPixelBufferHeightKey as String: Int(outputSize.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]

            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(outputSize.width),
                Int(outputSize.height),
                pixelFormat,
                attributes as CFDictionary,
                &pixelBuffer
            )

            if status != kCVReturnSuccess {
                return nil
            }
        }

        guard let buffer = pixelBuffer else { return nil }

        context.render(ciImage, to: buffer)

        return buffer
    }

    public static func createPixelBufferPool(
        size: CGSize,
        pixelFormat: OSType = kCVPixelFormatType_32BGRA,
        minimumBufferCount: Int = 6
    ) -> CVPixelBufferPool? {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: minimumBufferCount
        ]

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )

        return status == kCVReturnSuccess ? pool : nil
    }
}
