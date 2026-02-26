import os

struct IOLongpressRequest: Codable {
    let deviceId: String
    let x: Float
    let y: Float
    let duration: TimeInterval
}

@MainActor
struct IOLongpressMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.longpress"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let request = try decodeParams(IOLongpressRequest.self, from: params)

        let (width, height) = OrientationGeometry.physicalScreenSize()
        let point = OrientationGeometry.orientationAwarePoint(
            width: width,
            height: height,
            point: CGPoint(x: CGFloat(request.x), y: CGFloat(request.y))
        )

        logger.info("Long pressing \(point.x), \(point.y) for \(request.duration)s")

        do {
            let eventRecord = EventRecord(orientation: .portrait)
            _ = eventRecord.addPointerTouchEvent(
                at: point,
                touchUpAfter: request.duration
            )
            let start = Date()
            try await RunnerDaemonProxy().synthesize(eventRecord: eventRecord)
            let duration = Date().timeIntervalSince(start)
            logger.info("Tapping took \(duration)")
            return .object(["success": .bool(true)])
        } catch {
            logger.error("Error tapping: \(error)")
            throw RPCMethodError.internalError("Error tapping point: \(error.localizedDescription)")
        }
    }
}
