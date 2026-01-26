import os

struct AppsLaunchRequest : Codable {
    /// The app's to launch bundle id
    let bundleId: String

    /// Reserved for future use. Pass an empty array.
    let deviceId: String
}

// MARK: - Handler

/// JSON-RPC method handler for app launch operations.
///
/// This handler executes app launch based on the provide bundle id.
/// It uses XCTest's  APIs to activate the desired app
///
/// ## Method Name
/// `apps_launch
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
///## Example Request
/// ```json
/// {
///   "jsonrpc": "2.0",
///   "method": "apps_launch",
///   "params": {
///     "bundleId": "com.apple.mobilesafari",
///     "deviceId": "your_device_id"
///   },
///   "id": 1
/// }
///
/// ## Errors
/// - `-32602`: Invalid parameters (missing or malformed request)
/// - `-32603`: Internal error (app is not installed)
@MainActor
struct ApsLaunchMethodHandler: RPCMethodHandler {

    /// The JSON-RPC method name this handler responds to.
    static let methodName = "apps_launch"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Executes the app launch operation.
    ///
    /// - Parameter params: JSON-RPC parameters containing the bundle id to launch.
    /// - Returns: A JSON object with `success: true` on successful input.
    /// - Throws: `RPCMethodError.invalidParams` if parameters are invalid,
    ///           `RPCMethodError.internalError` if apps launch fails.
    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for apps_launch method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: AppsLaunchRequest
        do {
            request = try JSONDecoder().decode(AppsLaunchRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid apps_launch parameters: \(error.localizedDescription)")
        }

        let start = Date()

        logger.info("[Start] Launching app with bundle ID: \(request.bundleId)")
        XCUIApplication(bundleIdentifier: request.bundleId).activate()
        logger.info("[Done] Launching app with bundle ID: \(request.bundleId)")

        let duration = Date().timeIntervalSince(start)
        logger.info("Launch App duration took \(duration)")
        return .object(["success": .bool(true)])
    }

}

