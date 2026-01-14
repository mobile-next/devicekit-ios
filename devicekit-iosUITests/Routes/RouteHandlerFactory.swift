import Foundation
import FlyingFox

final class RouteHandlerFactory {
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
