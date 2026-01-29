import CoreGraphics
import CoreImage
import CoreVideo

/// Extensions for creating `CVPixelBuffer` from `CGImage` using GPU-accelerated Core Image.
///
/// This extension provides efficient pixel buffer creation by using `CIContext.render()`
/// instead of CPU-bound `CGContext.draw()`.
///
/// ## Performance
/// - GPU-accelerated rendering via Metal (when available)
/// - Significantly faster than CGContext.draw() for large images
/// - Supports pixel buffer pooling for memory efficiency
///
/// ## Usage
/// ```swift
/// let context = CIContext(options: [.useSoftwareRenderer: false])
/// let pixelBuffer = cgImage.toPixelBuffer(context: context, size: targetSize)
/// ```
extension CGImage {

    /// Creates a `CVPixelBuffer` from this CGImage using GPU-accelerated Core Image rendering.
    ///
    /// - Parameters:
    ///   - context: A `CIContext` for GPU rendering. Reuse this across frames for efficiency.
    ///   - targetSize: The output pixel buffer size. If different from the image size, the image is scaled.
    ///   - pixelFormat: The pixel format for the buffer. Defaults to 32-bit BGRA.
    ///   - pool: Optional pixel buffer pool for memory efficiency. If nil, a new buffer is allocated.
    /// - Returns: A `CVPixelBuffer` containing the rendered image, or `nil` on failure.
    ///
    /// ## Behavior
    /// - Creates a `CIImage` from this `CGImage`
    /// - Applies scaling transform if `targetSize` differs from image size
    /// - Renders to a `CVPixelBuffer` using GPU-accelerated `CIContext.render()`
    ///
    /// ## Performance Notes
    /// - Reuse the `CIContext` across multiple frames to avoid creation overhead
    /// - Use a `CVPixelBufferPool` for repeated conversions to reduce memory allocation
    /// - The Metal backend is used automatically when available
    public func toPixelBuffer(
        context: CIContext,
        targetSize: CGSize? = nil,
        pixelFormat: OSType = kCVPixelFormatType_32BGRA,
        pool: CVPixelBufferPool? = nil
    ) -> CVPixelBuffer? {
        // Create CIImage from CGImage
        var ciImage = CIImage(cgImage: self)

        // Determine output size
        let outputSize = targetSize ?? CGSize(width: width, height: height)

        // Apply scaling if needed
        let scaleX = outputSize.width / ciImage.extent.width
        let scaleY = outputSize.height / ciImage.extent.height
        if abs(scaleX - 1.0) > 0.001 || abs(scaleY - 1.0) > 0.001 {
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }

        // Get or create pixel buffer
        var pixelBuffer: CVPixelBuffer?

        if let pool = pool {
            // Allocate from pool
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            if status != kCVReturnSuccess {
                return nil
            }
        } else {
            // Create new pixel buffer with IOSurface backing for GPU compatibility
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

        // GPU-accelerated render from CIImage to CVPixelBuffer
        context.render(ciImage, to: buffer)

        return buffer
    }

    /// Creates a `CVPixelBufferPool` suitable for this image's dimensions.
    ///
    /// - Parameters:
    ///   - size: The dimensions for buffers in the pool.
    ///   - pixelFormat: The pixel format for buffers. Defaults to 32-bit BGRA.
    ///   - minimumBufferCount: Minimum number of buffers to keep in the pool.
    /// - Returns: A configured `CVPixelBufferPool`, or `nil` on failure.
    ///
    /// ## Usage
    /// Create a pool once and reuse it for all frame conversions:
    /// ```swift
    /// let pool = CGImage.createPixelBufferPool(size: targetSize, minimumBufferCount: 6)
    /// for image in frames {
    ///     let buffer = image.toPixelBuffer(context: ciContext, targetSize: targetSize, pool: pool)
    /// }
    /// ```
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
