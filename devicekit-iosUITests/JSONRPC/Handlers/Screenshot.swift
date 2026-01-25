import os

/// Constants used for screenshot encoding behavior.
private enum Constants {
    /// Default JPEG quality (1–100) used when the client does not specify one.
    static let defaultJpegQuality = 50
}

/// A JSON‑RPC request describing a screenshot capture operation.
///
/// The request specifies the target device, the desired output format,
/// and an optional JPEG quality value.
struct ScreenshotRequest: Codable {
    /// The target device identifier.
    let deviceId: String
    
    /// The output image format. Supported values: `"png"`, `"jpeg"`, `"jpg"`.
    let format: String
    
    /// Optional JPEG quality (1–100). Only used when `format` is JPEG.
    let quality: Int?
    
    /// Output path. Currently unused; always returns inline Base64 data.
    let outputPath = "-"
}

/// JSON‑RPC method handler for capturing screenshots from an iOS device.
///
/// This handler captures a full‑screen image using XCTest’s `XCUIScreen`,
/// encodes it as PNG or JPEG, and returns the Base64‑encoded data inline
/// in the JSON‑RPC response.
///
/* Example with curl
 curl -s -X POST http://localhost:12004/rpc \
 -H "Content-Type: application/json" \
 -d '{"jsonrpc":"2.0","method":"screenshot","params":{"deviceId":"ll","format":"png"},"id":2}' \
 | jq -r '.result.data' \
 | sed 's/data:image\/png;base64,//' \
 | base64 --decode > screenshot.png && open screenshot.png
 */
///
@MainActor
struct ScreenshotMethodHandler: RPCMethodHandler {
    
    /// The JSON‑RPC method name exposed by this handler.
    static let methodName = "screenshot"
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )
    
    /// Executes the `screenshot` JSON‑RPC method.
    ///
    /// - Parameter params: The JSON‑RPC parameters containing screenshot options.
    /// - Returns: A JSON object containing the encoded screenshot:
    ///
    ///   ```json
    ///   {
    ///     "format": "png",
    ///     "data": "data:image/png;base64,<...>"
    ///   }
    ///   ```
    ///
    /// - Throws:
    ///   - `RPCMethodError.invalidParams` if the request cannot be decoded
    ///     or the format is unsupported.
    ///   - `RPCMethodError.internalError` if screenshot capture fails.
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
