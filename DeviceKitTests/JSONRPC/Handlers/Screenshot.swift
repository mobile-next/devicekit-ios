import os

private enum Constants {
    static let defaultJpegQuality = 50
}

struct ScreenshotRequest: Codable {
    let format: String
    let quality: Int?
    var outputPath: String = "-"
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
        
        // Capture screenshot
        let fullScreenshot = XCUIScreen.main.screenshot()
        var imageData: Data?
        
        switch request.format.lowercased() {
        case "png":
            imageData = fullScreenshot.pngRepresentation
            
        case "jpg", "jpeg":
            let clampedQuality = min(max(request.quality ?? Constants.defaultJpegQuality, 0), 100)
            imageData = fullScreenshot.image.jpegData(compressionQuality: Double(clampedQuality) / 100.0)
            
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
}
