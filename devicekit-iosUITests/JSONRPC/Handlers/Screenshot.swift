import os

private enum Constants {
    static let defaultJpegQuality = 50
}

struct ScreenshotRequest: Codable {
    let deviceId: String
    let format: String
    let quality: Int?
    let outputPath = "-"
}

@MainActor
struct ScreenshotMethodHandler: RPCMethodHandler {
    static let methodName = "screenshot"
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )
    
    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for screenshot method")
        }
        
        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }
        
        let request: ScreenshotRequest
        do {
            request = try JSONDecoder().decode(ScreenshotRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid screenshot parameters: \(error.localizedDescription)")
        }
        
        // Capture screenshot
        let fullScreenshot = XCUIScreen.main.screenshot()
        var imageData: Data?
        
        switch request.format.lowercased() {
        case "png":
            imageData = fullScreenshot.pngRepresentation
            
        case "jpg", "jpeg":
            let quality = Double(request.quality ?? Constants.defaultJpegQuality) / 100.0
            imageData = fullScreenshot.image.jpegData(compressionQuality: quality)
            
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
