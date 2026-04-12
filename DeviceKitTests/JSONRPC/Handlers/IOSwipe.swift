import os

private enum Constants {
    static let defaultSwipeDuration = 0.1
}

struct IOSwipeRequest: Decodable {
    let x1: Int
    let y1: Int
    let x2: Int
    let y2: Int
}

@MainActor
struct IOSwipeMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.swipe"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let request = try decodeParams(IOSwipeRequest.self, from: params)

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
