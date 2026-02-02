import FlyingFox
import Foundation
import os

extension String {
    /// Converts the string to a UInt16 port number.
    /// - Returns: The port number if conversion succeeds, `nil` otherwise.
    func toUInt16() -> UInt16? {
        return UInt16(self)
    }
}

// MARK: - WebSocket HTTP & JSON-RPC Server

/// WebSocket server with JSON-RPC 2.0 protocol for UI automation.
///
/// This server provides a WebSocket endpoint that accepts JSON-RPC requests
/// and returns JSON-RPC responses for programmatic device control.
///
/// ## Configuration
/// - **Host**: `127.0.0.1` (localhost only)
/// - **Port**: `12004` (configurable via `PORT` environment variable)
/// - **Endpoint**: `ws://127.0.0.1:12004/rpc`
///
/// ## Starting the Server
/// ```swift
/// let server = XCTestServer()
/// try await server.start()  // Blocks until shutdown
/// ```
///
/// ## JSON-RPC Methods
///
/// ### io_tap
/// Performs a tap or long-press at specified coordinates.
/// ```json
/// // Request
/// {"jsonrpc": "2.0", "method": "io_tap", "params": {"x": 100.0, "y": 200.0}, "id": 1}
///
/// // Response
/// {"jsonrpc": "2.0", "result": {"success": true}, "id": 1}
/// ```
///
/// ### dump_ui
/// Returns the complete view hierarchy.
/// ```json
/// // Request
/// {"jsonrpc": "2.0", "method": "dump_ui", "params": {"appIds": [], "excludeKeyboardElements": false}, "id": 2}
///
/// // Response
/// {"jsonrpc": "2.0", "result": {"axElement": {...}, "depth": 15}, "id": 2}
/// ```
///
/// ## Client Example (JavaScript)
/// ```javascript
/// const ws = new WebSocket('ws://127.0.0.1:12004/rpc');
/// ws.onopen = () => {
///     ws.send(JSON.stringify({
///         jsonrpc: '2.0',
///         method: 'io_tap',
///         params: { x: 100, y: 200 },
///         id: 1
///     }));
/// };
/// ws.onmessage = (event) => {
///     const response = JSON.parse(event.data);
///     console.log(response);
/// };
/// ```
@MainActor
final class XCTestServer {

    /// Default timeout for WebSocket operations.
    private let defaultTimeout: TimeInterval = 100

    /// Default port for the WebSocket server.
    private let defaultPort: UInt16 = 12004

    /// Server binds to localhost only.
    private let localhost = "127.0.0.1"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "XCTestServer"
    )

    /// JSON-RPC dispatcher for routing method calls.
    private let dispatcher: JSONRPCDispatcher

    /// Initializes the WebSocket server.
    init() {
        self.dispatcher = JSONRPCDispatcher()
    }

    /// Starts the WebSocket server and blocks until shutdown.
    ///
    /// The server creates a WebSocket endpoint at `/rpc` that processes
    /// JSON-RPC requests and returns responses.
    ///
    /// - Throws: An error if the server fails to bind or encounters a runtime error.
    func start() async throws {
        let port = ProcessInfo.processInfo.environment["PORT"]?.toUInt16() ?? defaultPort
        let server = HTTPServer(
            address: try .inet(ip4: localhost, port: port),
            timeout: defaultTimeout
        )

        logger.info("Starting JSON-RPC server on \(self.localhost):\(port)")

        // WebSocket endpoint for JSON-RPC (GET /rpc with WebSocket upgrade)
        let messageHandler = JSONRPCMessageHandler(dispatcher: dispatcher)
        let frameHandler = MessageFrameWSHandler(handler: messageHandler)
        let wsHandler = WebSocketHTTPHandler(handler: frameHandler)
        await server.appendRoute("GET /rpc", to: wsHandler)

        // HTTP POST endpoint for JSON-RPC (for curl/REST clients)
        let httpHandler = JSONRPCHTTPHandler(dispatcher: dispatcher)
        await server.appendRoute("POST /rpc", to: httpHandler)

        // Health check endpoint (HTTP)
        await server.appendRoute("GET /health") { _ in
            HTTPResponse(statusCode: .ok, body: Data("OK".utf8))
        }

        // MJPEG streaming endpoint
        let mjpegHandler = MJPEGHTTPHandler()
        await server.appendRoute("GET /mjpeg", to: mjpegHandler)

        // H264 streaming endpoint
        let h264Handler = H264HTTPHandler()
        await server.appendRoute("GET /h264", to: h264Handler)

        logger.info("Server is ready (WebSocket: ws://\(self.localhost):\(port)/rpc, HTTP: POST http://\(self.localhost):\(port)/rpc, MJPEG: http://\(self.localhost):\(port)/mjpeg, H264: http://\(self.localhost):\(port)/h264)")
        try await server.run()
    }
}

