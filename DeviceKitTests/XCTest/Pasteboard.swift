import Foundation
import UIKit
import XCTest
import os

private enum Constants {
    static let alertTimeout: TimeInterval = 30
    static let alertCheckInterval: TimeInterval = 0.5
}

private final class PasteboardRead: @unchecked Sendable {
    private let lock = NSLock()
    private var storedText: String?
    private var isFinished = false

    var finished: Bool {
        lock.withLock { isFinished }
    }

    var text: String? {
        lock.withLock { storedText }
    }

    func complete(with text: String?) {
        lock.withLock {
            storedText = text
            isFinished = true
        }
    }
}

@MainActor
struct Pasteboard {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "devicekit-ios",
        category: String(describing: Self.self)
    )

    private init() {}

    // iOS only hands the general pasteboard to the foreground application, so
    // the runner is brought forward for the access and whatever was in front
    // before is restored afterwards.
    static func withRunnerInForeground<T>(_ body: () async throws -> T) async throws -> T {
        guard let runnerBundleId = Bundle.main.bundleIdentifier else {
            throw RPCMethodError.internalError("Cannot determine the runner bundle identifier")
        }

        let runner = XCUIApplication(bundleIdentifier: runnerBundleId)
        let previousBundleId = RunningApp.getForegroundApp()?.bundleID
        let needsActivation = runner.state != .runningForeground

        if needsActivation {
            logger.info("Activating the runner for pasteboard access")
            runner.activate()
        }

        do {
            let result = try await body()
            restore(previousBundleId, runnerBundleId: runnerBundleId, wasActivated: needsActivation)
            return result
        } catch {
            restore(previousBundleId, runnerBundleId: runnerBundleId, wasActivated: needsActivation)
            throw error
        }
    }

    private static func restore(
        _ previousBundleId: String?,
        runnerBundleId: String,
        wasActivated: Bool
    ) {
        guard wasActivated,
              let previousBundleId = previousBundleId,
              previousBundleId != runnerBundleId else {
            return
        }

        logger.info("Restoring \(previousBundleId) to the foreground")
        XCUIApplication(bundleIdentifier: previousBundleId).activate()
    }

    static func write(_ text: String) throws {
        let pasteboard = UIPasteboard.general

        let failure = RPCMethodError.internalError(
            "Pasteboard write did not take effect; it is only available while the device is unlocked"
        )

        if text.isEmpty {
            pasteboard.items = []
            guard !pasteboard.hasStrings else {
                throw failure
            }
        } else {
            pasteboard.string = text
            guard pasteboard.string == text else {
                throw failure
            }
        }
    }

    static func readText() async throws -> String {
        guard UIPasteboard.general.hasStrings else {
            return ""
        }

        let read = PasteboardRead()
        DispatchQueue.global().async {
            read.complete(with: UIPasteboard.general.string)
        }

        let deadline = Date().addingTimeInterval(Constants.alertTimeout)
        while !read.finished {
            try await Task.sleep(nanoseconds: UInt64(Constants.alertCheckInterval * 1_000_000_000))
            if read.finished {
                break
            }
            acceptConsentAlert()
            if Date() > deadline {
                throw RPCMethodError.internalError(
                    "Pasteboard read did not complete within \(Constants.alertTimeout)s"
                )
            }
        }

        return read.text ?? ""
    }

    private static func acceptConsentAlert() {
        let springboard = XCUIApplication(bundleIdentifier: RunningApp.springboardBundleId)
        let alert = springboard.alerts.firstMatch
        guard alert.exists else {
            return
        }

        let buttons = alert.buttons
        let count = buttons.count
        guard count > 0 else {
            return
        }

        logger.info("Accepting the pasteboard consent alert")
        buttons.element(boundBy: count - 1).tap()
    }
}
