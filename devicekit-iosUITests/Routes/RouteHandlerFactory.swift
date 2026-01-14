import Foundation
import FlyingFox

// MARK: - Route Handler Factory

/// Factory for creating HTTP route handlers.
///
/// This factory maps each `Route` case to its corresponding handler implementation.
/// All handlers must conform to FlyingFox's `HTTPHandler` protocol.
///
/// ## Supported Routes
///
/// | Route | Handler | Description |
/// |-------|---------|-------------|
/// | `/tap` | `TapRouteHandler` | Touch event synthesis |
/// | `/dumpUI` | `DumpUIHandler` | View hierarchy capture |
///
/// ## Usage
/// ```swift
/// let handler = await RouteHandlerFactory.createRouteHandler(route: .tap)
/// await server.appendRoute(HTTPRoute("tap"), to: handler)
/// ```
final class RouteHandlerFactory {

    /// Creates the appropriate handler for the given route.
    ///
    /// - Parameter route: The route to create a handler for.
    /// - Returns: An `HTTPHandler` instance configured for the specified route.
    ///
    /// - Note: This method must be called on the main actor as handlers
    ///   interact with XCTest UI automation APIs.
    @MainActor
    static func createRouteHandler(route: Route) -> HTTPHandler {
        switch route {
        case .tap:
            return TapRouteHandler()
        case .dumpUI:
            return DumpUIHandler()
        }
    }
}
