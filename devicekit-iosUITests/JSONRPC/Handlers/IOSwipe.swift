import os

private enum Constants {
    static let defaultSwipeDuration = 0.1
}

struct IOSwipeRequest: Decodable {
    let deviceId: String
    let x1: Int
    let y1: Int
    let x2: Int
    let y2: Int
}

@MainActor
struct IOSwipeMethodHandler: RPCMethodHandler {
    static let methodName = "io_swipe"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for io_swipe method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: IOSwipeRequest
        do {
            request = try JSONDecoder().decode(IOSwipeRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid io_swipe parameters: \(error.localizedDescription)")
        }

        do {
            try await swipePrivateAPI(
                start: CGPoint(x: request.x1, y: request.y1),
                end: CGPoint(x: request.x2, y: request.y2),
                duration: Constants.defaultSwipeDuration
            )

            return .object(["success": .bool(true)])
        } catch {
            logger.error("Error performing swipe: \(error)")
            throw RPCMethodError.internalError("Error performing swipe: \(error.localizedDescription)")
        }
    }

    func swipePrivateAPI(start: CGPoint, end: CGPoint, duration: Double) async throws {
        logger.info("Swipe (v1) from \(start.debugDescription) to \(end.debugDescription) with duration \(duration)")

        let eventRecord = EventRecord(orientation: .portrait)
        _ = eventRecord.addSwipeEvent(start: start, end: end, duration: duration)

        try await RunnerDaemonProxy().synthesize(eventRecord: eventRecord)
    }
}
