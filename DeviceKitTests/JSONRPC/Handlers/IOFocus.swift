import XCTest
import os

#if os(tvOS)

/// Parameters for `device.io.focus`.
///
/// The target element is selected by accessibility `identifier` and/or `label`.
/// At least one of `identifier`/`label` must be supplied. `elementType` is an
/// optional hint carried for forward compatibility.
struct IOFocusRequest: Codable {
    let identifier: String?
    let label: String?
    let elementType: String?
}

@MainActor
struct IOFocusMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.focus"

    /// Upper bound on Siri Remote moves before giving up (D3).
    private static let maxMoves = 50

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let request = try decodeParams(IOFocusRequest.self, from: params)

        let identifier = request.identifier.flatMap { $0.isEmpty ? nil : $0 }
        let label = request.label.flatMap { $0.isEmpty ? nil : $0 }

        guard identifier != nil || label != nil else {
            throw RPCMethodError.invalidParams(
                "device.io.focus requires at least one of 'identifier' or 'label'"
            )
        }

        let selectorDescription = Self.selectorDescription(identifier: identifier, label: label)

        guard let app = RunningApp.getForegroundApp() else {
            throw RPCMethodError.internalError(
                "device.io.focus: no foreground app to search for [\(selectorDescription)]"
            )
        }

        let target = app.descendants(matching: .any)
            .matching(Self.matchPredicate(identifier: identifier, label: label))
            .firstMatch

        guard target.exists else {
            throw focusFailure(
                selector: selectorDescription,
                moves: 0,
                lastFocused: focusedElement(in: app),
                reason: "target element not found"
            )
        }

        var lastFocused = focusedElement(in: app)
        // Signature (identifier + frame) of the focused element captured just
        // before the last press, used to detect a no-progress dead end.
        var previousSignature: (identifier: String, frame: CGRect)?
        var movesTaken = 0
        var noProgress = false

        for move in 0...Self.maxMoves {
            movesTaken = move
            guard let focused = focusedElement(in: app) else {
                // No focusable element currently; nudge with a right press and retry.
                if move < Self.maxMoves {
                    XCUIRemote.shared.press(.right)
                    continue
                }
                break
            }
            lastFocused = focused

            if matches(focused, identifier: identifier, label: label) {
                logger.info("[Done] Focused [\(selectorDescription)] after \(move) move(s)")
                return try serialize(focused)
            }

            // No-progress early exit: if the last press did not change the
            // focused element (same identifier + frame), we are at a dead end
            // or oscillating — fail early instead of burning all 50 moves.
            let currentSignature = (identifier: focused.identifier, frame: focused.frame)
            if let previousSignature,
               previousSignature.identifier == currentSignature.identifier,
               previousSignature.frame == currentSignature.frame {
                noProgress = true
                break
            }

            if move == Self.maxMoves { break }

            // Re-read the target's frame each iteration: on tvOS, moving focus
            // scrolls the container and shifts the target's on-screen frame, so
            // a centre computed once before the loop would be stale.
            let targetCenter = center(of: target.frame)
            let focusedCenter = center(of: currentSignature.frame)
            let dx = targetCenter.x - focusedCenter.x
            let dy = targetCenter.y - focusedCenter.y
            let direction: XCUIRemote.Button
            if abs(dx) > abs(dy) {
                direction = dx > 0 ? .right : .left
            } else {
                direction = dy > 0 ? .down : .up
            }
            logger.info("Focus move \(move): pressing \(String(describing: direction)) toward [\(selectorDescription)]")
            XCUIRemote.shared.press(direction)
            previousSignature = currentSignature
        }

        let reason = noProgress
            ? "focus did not change after \(movesTaken) move(s) (dead end or oscillation)"
            : "element not focused after \(Self.maxMoves) move(s)"
        throw focusFailure(
            selector: selectorDescription,
            moves: noProgress ? movesTaken : Self.maxMoves,
            lastFocused: lastFocused,
            reason: reason
        )
    }

    // MARK: - Helpers

    private func focusedElement(in app: XCUIApplication) -> XCUIElement? {
        let focused = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true"))
            .firstMatch
        return focused.exists ? focused : nil
    }

    private func matches(_ element: XCUIElement, identifier: String?, label: String?) -> Bool {
        if let identifier, element.identifier == identifier { return true }
        if let label, element.label == label { return true }
        return false
    }

    private func center(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    private func serialize(_ element: XCUIElement) throws -> JSONValue {
        do {
            let snapshotDictionary = try element.snapshot().dictionaryRepresentation
            let sourceTree = SourceTreeElement(axElement: AXElement(snapshotDictionary))
            return try JSONValue.from(sourceTree)
        } catch {
            throw RPCMethodError.internalError(
                "device.io.focus: failed to serialize element snapshot: \(error.localizedDescription)"
            )
        }
    }

    private func focusFailure(
        selector: String,
        moves: Int,
        lastFocused: XCUIElement?,
        reason: String
    ) -> RPCMethodError {
        var data: JSONValue?
        if let lastFocused, lastFocused.exists {
            // Wrapped in serialize(), which converts any snapshot/serialisation
            // failure into an internalError; swallowed here so the failure path
            // still returns the -32002 focusNotFound error with best-effort data.
            data = try? serialize(lastFocused)
        }
        let message = "device.io.focus could not focus element matching [\(selector)] (\(reason))"
        return RPCMethodError.focusNotFound(message: message, data: data)
    }

    private static func matchPredicate(identifier: String?, label: String?) -> NSPredicate {
        if let identifier, let label {
            return NSPredicate(format: "identifier == %@ OR label == %@", identifier, label)
        } else if let identifier {
            return NSPredicate(format: "identifier == %@", identifier)
        } else {
            return NSPredicate(format: "label == %@", label ?? "")
        }
    }

    private static func selectorDescription(identifier: String?, label: String?) -> String {
        var parts: [String] = []
        if let identifier { parts.append("identifier=\(identifier)") }
        if let label { parts.append("label=\(label)") }
        return parts.joined(separator: ", ")
    }
}

#endif
