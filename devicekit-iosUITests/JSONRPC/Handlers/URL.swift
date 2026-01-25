import Foundation
import os

// MARK: - Request Model

/// Parameters for the `open_url` JSON-RPC method.
///
/// ## JSON Format
/// ```json
/// {
///   "url": "https://example.com"
/// }
/// ```
///
/// ## Fields
/// - `url`: The URL string to open. Supports any URL scheme (http, https, tel, mailto, etc.).
///
/// ## Example Request
/// ```json
/// {
///   "jsonrpc": "2.0",
///   "method": "open_url",
///   "params": {
///     "url": "https://www.apple.com"
///   },
///   "id": 1
/// }
/// ```
struct URLRequest: Codable {
    /// The target device identifier.
    let deviceId: String

    /// The URL to open in the default application.
    let url: String
}

// MARK: - Handler

/// JSON-RPC method handler for opening URLs.
///
/// This handler opens URLs using the system's default application for each URL scheme.
/// For `http://` and `https://` URLs, this typically opens Safari.
/// For other schemes (`tel:`, `mailto:`, `maps:`, etc.), the appropriate system app handles the URL.
///
/// ## Method Name
/// `open_url`
///
/// ## Implementation Details
/// Uses XCTest's private `openDefaultApplicationForURL:completion:` API (available since Xcode 14.3)
/// to open URLs through the XCTest daemon session.
///
/// ## Response
/// ```json
/// {
///   "jsonrpc": "2.0",
///   "result": { "success": true },
///   "id": 1
/// }
/// ```
///
/// ## Errors
/// - `-32602`: Invalid parameters (missing URL, malformed URL, or invalid URL scheme)
/// - `-32603`: Internal error (failed to open URL)
///
/// ## Supported URL Schemes
/// - `http://`, `https://` - Opens in Safari
/// - `tel:` - Opens Phone app
/// - `mailto:` - Opens Mail app
/// - `maps:` - Opens Maps app
/// - Custom app URL schemes
@MainActor
struct URLMethodHandler: RPCMethodHandler {

    /// The JSON-RPC method name this handler responds to.
    static let methodName = "open_url"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Executes the URL open operation.
    ///
    /// - Parameter params: JSON-RPC parameters containing the URL to open.
    /// - Returns: A JSON object with `success: true` on successful URL open.
    /// - Throws: `RPCMethodError.invalidParams` if parameters are invalid,
    ///           `RPCMethodError.internalError` if URL open fails.
    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for open_url method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: URLRequest
        do {
            request = try JSONDecoder().decode(URLRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid open_url parameters: \(error.localizedDescription)")
        }

        guard let url = URL(string: request.url) else {
            throw RPCMethodError.invalidParams("Invalid URL format: '\(request.url)'")
        }

        do {
            let start = Date()
            try await openURL(url)
            let duration = Date().timeIntervalSince(start)
            logger.info("URL open took \(duration)s for: \(request.url)")
            return .object(["success": .bool(true)])
        } catch {
            logger.error("Error opening URL: \(error)")
            throw RPCMethodError.internalError("Error opening URL: \(error.localizedDescription)")
        }
    }

    /// Opens a URL using the system's default application.
    ///
    /// Uses XCTest's private `openDefaultApplicationForURL:completion:` API to open
    /// the URL through the XCTest daemon session.
    ///
    /// - Parameter url: The URL to open.
    /// - Throws: Error if the URL cannot be opened.
    private func openURL(_ url: URL) async throws {
        // Get the shared XCTRunnerDaemonSession
        let sessionClass: AnyClass = NSClassFromString("XCTRunnerDaemonSession")!
        let sharedSelector = NSSelectorFromString("sharedSession")
        let sharedImp = sessionClass.method(for: sharedSelector)
        typealias SharedMethod = @convention(c) (AnyClass, Selector) -> NSObject
        let sharedMethod = unsafeBitCast(sharedImp, to: SharedMethod.self)
        let session = sharedMethod(sessionClass, sharedSelector)

        // Call openDefaultApplicationForURL:completion:
        let openSelector = NSSelectorFromString("openDefaultApplicationForURL:completion:")
        let openImp = session.method(for: openSelector)
        typealias OpenMethod = @convention(c) (
            NSObject,
            Selector,
            NSURL,
            @escaping (Bool, Error?) -> Void
        ) -> Void
        let openMethod = unsafeBitCast(openImp, to: OpenMethod.self)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            openMethod(session, openSelector, url as NSURL) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if !success {
                    continuation.resume(throwing: NSError(
                        domain: "URLMethodHandler",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to open URL"]
                    ))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
