import os

struct IOTapRequest: Codable {
    let deviceId: String
    let x: Float
    let y: Float
}

@MainActor
struct IOTapMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.tap"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for io_tap method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: IOTapRequest
        do {
            request = try JSONDecoder().decode(IOTapRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid io_tap parameters: \(error.localizedDescription)")
        }

        let (width, height) = OrientationGeometry.physicalScreenSize()
        let point = OrientationGeometry.orientationAwarePoint(
            width: width,
            height: height,
            point: CGPoint(x: CGFloat(request.x), y: CGFloat(request.y))
        )
        let (x, y) = (point.x, point.y)

        do {
            let eventRecord = EventRecord(orientation: .portrait)
            _ = eventRecord.addPointerTouchEvent(
                at: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                touchUpAfter: nil
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

