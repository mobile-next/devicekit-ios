import FlyingFox
import Foundation

enum Route: String, CaseIterable {
    case tap
    case dumpUI

    func toHTTPRoute() -> HTTPRoute {
        return HTTPRoute(rawValue)
    }
}

private let defaultTimeout: TimeInterval = 100
private let defaultPort: UInt16 = 12004
private let localhost = "127.0.0.1"

final class XCTestHTTPServer {
    func start() async throws {
        let port = ProcessInfo.processInfo.environment["PORT"]?.toUInt16() ?? defaultPort
        let server = HTTPServer(address: try .inet(ip4: localhost, port: port), timeout: defaultTimeout)
        
        for route in Route.allCases {
            let handler = await RouteHandlerFactory.createRouteHandler(route: route)
            await server.appendRoute(route.toHTTPRoute(), to: handler)
        }
        
        try await server.run()
    }
}
