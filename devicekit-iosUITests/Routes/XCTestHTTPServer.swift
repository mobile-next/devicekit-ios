import FlyingFox
import Foundation

// MARK: - Route Definition

/// Defines all available HTTP routes for the automation server.
///
/// Each route maps to a specific handler that processes incoming requests.
///
/// ## Available Routes
/// - `tap`: Performs tap/long-press gestures at screen coordinates
/// - `dumpUI`: Captures the complete UI view hierarchy
///
/// ## Example Usage
/// ```bash
/// # Tap endpoint
/// curl -X POST http://127.0.0.1:12004/tap \
///     -H "Content-Type: application/json" \
///     -d '{"x": 100.0, "y": 200.0}'
///
/// # DumpUI endpoint
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": false}'
/// ```
enum Route: String, CaseIterable {
    /// Tap or long-press gesture endpoint.
    /// - Method: POST
    /// - Path: `/tap`
    case tap

    /// UI hierarchy dump endpoint.
    /// - Method: POST
    /// - Path: `/dumpUI`
    case dumpUI

    /// Converts the route case to an HTTP route path.
    /// - Returns: An `HTTPRoute` with the path matching the raw value (e.g., "/tap").
    func toHTTPRoute() -> HTTPRoute {
        return HTTPRoute(rawValue)
    }
}

// MARK: - String Extension

extension String {
    /// Converts the string to a UInt16 port number.
    /// - Returns: The port number if conversion succeeds, `nil` otherwise.
    func toUInt16() -> UInt16? {
        return UInt16(self)
    }
}

// MARK: - Server Configuration

/// Default timeout for HTTP requests (100 seconds).
private let defaultTimeout: TimeInterval = 100

/// Default port for the HTTP server.
private let defaultPort: UInt16 = 12004

/// Server binds to localhost only.
private let localhost = "127.0.0.1"

// MARK: - HTTP Server

/// HTTP server for UI automation control during XCTest execution.
///
/// This server provides REST endpoints for programmatic device control,
/// including tap gestures and UI hierarchy inspection.
///
/// ## Configuration
/// - **Host**: `127.0.0.1` (localhost only)
/// - **Port**: `12004` (configurable via `PORT` environment variable)
/// - **Timeout**: `100` seconds
///
/// ## Starting the Server
/// The server is started automatically during test execution:
/// ```swift
/// let server = XCTestHTTPServer()
/// try await server.start()  // Blocks until shutdown
/// ```
///
/// ## Available Endpoints
///
/// ### POST /tap
/// Performs a tap or long-press at specified coordinates.
/// ```bash
/// curl -X POST http://127.0.0.1:12004/tap \
///     -H "Content-Type: application/json" \
///     -d '{"x": 100.0, "y": 200.0}'
/// ```
///
/// ### POST /dumpUI
/// Returns the complete view hierarchy as JSON.
/// ```bash
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": false}'
/// ```
final class XCTestHTTPServer {

    /// Starts the HTTP server and blocks until shutdown.
    ///
    /// The server registers all routes defined in `Route` enum and begins
    /// accepting connections on the configured address.
    ///
    /// - Throws: An error if the server fails to bind or encounters a runtime error.
    ///
    /// - Note: This method blocks the calling task until the server is stopped.
    ///   The port can be configured via the `PORT` environment variable.
    func start() async throws {
        let port =
            ProcessInfo.processInfo.environment["PORT"]?.toUInt16()
            ?? defaultPort
        let server = HTTPServer(
            address: try .inet(ip4: localhost, port: port),
            timeout: defaultTimeout
        )

        for route in Route.allCases {
            let handler = await RouteHandlerFactory.createRouteHandler(
                route: route
            )
            await server.appendRoute(route.toHTTPRoute(), to: handler)
        }

        try await server.run()
    }
}
