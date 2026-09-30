import os

private enum Constants {
    static let defaultJpegQuality = 50
    static let blankCheckSide = 16
}

struct ScreenshotRequest: Codable {
    let format: String
    let quality: Int?
    let outputPath = "-"

    private enum CodingKeys: String, CodingKey {
        case format, quality
    }
}

@MainActor
struct ScreenshotMethodHandler: RPCMethodHandler {
    static let methodName = "device.screenshot"
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )
    
    func execute(params: JSONValue?) async throws -> JSONValue {
        let request = try decodeParams(ScreenshotRequest.self, from: params)
        
        let fullScreenshot = captureActiveScreen()
        let rotated = pixelsRotatedUpright(fullScreenshot.image)
        var imageData: Data?
        
        switch request.format.lowercased() {
        case "png":
            imageData = rotated?.pngData() ?? fullScreenshot.pngRepresentation
            
        case "jpg", "jpeg":
            let clampedQuality = min(max(request.quality ?? Constants.defaultJpegQuality, 0), 100)
            let image = rotated ?? fullScreenshot.image
            imageData = image.jpegData(compressionQuality: Double(clampedQuality) / 100.0)
            
        default:
            throw RPCMethodError.invalidParams("Unsupported image format: \(request.format)")
        }
        
        guard let imageData else {
            throw RPCMethodError.internalError("Failed to encode screenshot in format: \(request.format)")
        }
        
        return .object([
            "format": .string(request.format),
            "data": .string("data:image/\(request.format);base64,\(imageData.base64EncodedString())")
        ])
    }

    /// XCTest hands a rotated screen back as the panel's portrait pixels plus an orientation,
    /// which the encoders write as an EXIF tag. Decoders disagree on honouring that tag, so
    /// redraw the image with the rotation applied to the pixels themselves.
    /// Returns nil when the image is already upright.
    private func pixelsRotatedUpright(_ image: UIImage) -> UIImage? {
        guard image.imageOrientation != .up else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Foldables (e.g. iPhone Duo) have two screens and XCUIScreen.main is always the cover screen,
    /// which is fully black while the device is unfolded. Fall back to the screen that is showing content.
    private func captureActiveScreen() -> XCUIScreenshot {
        let mainScreenshot = XCUIScreen.main.screenshot()
        guard XCUIScreen.screens.count > 1, isBlank(mainScreenshot.image) else {
            return mainScreenshot
        }

        for screen in XCUIScreen.screens where screen != XCUIScreen.main {
            let screenshot = screen.screenshot()
            if !isBlank(screenshot.image) {
                logger.info("Main screen is blank, using screen \(screen)")
                return screenshot
            }
        }
        return mainScreenshot
    }

    /// An inactive screen is exactly black; downsample and look for any non-zero pixel
    private func isBlank(_ image: UIImage) -> Bool {
        let side = Constants.blankCheckSide
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else {
                return false
            }
            // UIImage.draw also handles screenshots that are not CGImage-backed
            UIGraphicsPushContext(context)
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
            UIGraphicsPopContext()
            return true
        }
        // every 4th byte is the skipped alpha channel, only RGB matters
        let maxColor = pixels.enumerated().filter { $0.offset % 4 != 3 }.map(\.element).max() ?? 0
        logger.debug("Blank check: drawn=\(drawn) maxColor=\(maxColor) size=\(image.size.debugDescription)")
        return drawn && maxColor == 0
    }
}
