import FlyingFox
import XCTest
import os

// MARK: - Logger Extension

extension Logger {
    /// Measures and logs the execution time of a block.
    ///
    /// - Parameters:
    ///   - message: Description of the operation being measured.
    ///   - block: The block to execute and measure.
    /// - Returns: The result of the block execution.
    func measure<T>(message: String, _ block: () throws -> T) rethrows -> T {
        let start = Date()
        info("\(message) - start")

        let result = try block()

        let duration = Date().timeIntervalSince(start)
        NSLog("\(message) - duration \(duration)")

        return result
    }
}

// MARK: - DumpUI Request Model

/// Request body for the `/dumpUI` endpoint.
///
/// This model represents the JSON payload for capturing the UI view hierarchy.
///
/// ## JSON Format
/// ```json
/// {
///   "appIds": [],
///   "excludeKeyboardElements": false
/// }
/// ```
///
/// ## curl Examples
/// ```bash
/// # Capture full UI hierarchy
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": false}'
///
/// # Exclude keyboard from hierarchy
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": true}'
///
/// # Pretty-print JSON output
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": false}' | jq .
/// ```
struct DumpUIRequest: Codable {

    /// Array of bundle identifiers to target.
    /// - Empty array `[]`: Captures the current foreground application.
    /// - Specific IDs: Targets the specified applications.
    let appIds: [String]

    /// Whether to exclude keyboard UI elements from the hierarchy.
    /// - `true`: Filters out all keyboard-related elements.
    /// - `false`: Includes keyboard elements in the response.
    let excludeKeyboardElements: Bool
}

// MARK: - DumpUI Handler

/// HTTP handler for capturing the complete UI view hierarchy.
///
/// This handler processes POST requests to the `/dumpUI` endpoint and returns
/// a JSON representation of the accessibility element tree for the foreground app.
///
/// ## Endpoint
/// - **Method**: POST
/// - **Path**: `/dumpUI`
/// - **Content-Type**: `application/json`
///
/// ## Request Format
/// ```json
/// {
///   "appIds": [],
///   "excludeKeyboardElements": false
/// }
/// ```
///
/// | Field | Type | Required | Description |
/// |-------|------|----------|-------------|
/// | `appIds` | [String] | Yes | Bundle IDs to target (can be empty) |
/// | `excludeKeyboardElements` | Bool | Yes | Filter out keyboard elements |
///
/// ## Response Format
/// ```json
/// {
///   "axElement": {
///     "identifier": "element_id",
///     "frame": {"X": 0, "Y": 0, "Width": 390, "Height": 844},
///     "label": "Accessibility Label",
///     "elementType": 1,
///     "enabled": true,
///     "children": [...]
///   },
///   "depth": 15
/// }
/// ```
///
/// ## Response Codes
/// - **200 OK**: View hierarchy captured successfully
/// - **400 Bad Request**: Invalid request body
/// - **408 Request Timeout**: Snapshot operation timed out
/// - **500 Internal Server Error**: Snapshot failure
///
/// ## curl Examples
/// ```bash
/// # Basic UI dump
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": false}'
///
/// # Exclude keyboard elements
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": true}'
///
/// # Pretty-print with jq
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": false}' | jq .
/// ```
///
/// ## Implementation Details
/// - Automatically detects the foreground application
/// - Handles deep view hierarchies with fallback mechanisms (max depth: 60)
/// - Includes status bar, keyboard, and alert elements
/// - Supports Safari WebView capture on iOS 26+
/// - Adjusts frame offsets for non-standard window sizes
@MainActor
struct DumpUIHandler: HTTPHandler {

    /// SpringBoard application for system UI access.
    private let springboardApplication = XCUIApplication(
        bundleIdentifier: "com.apple.springboard"
    )

    /// Maximum depth for view hierarchy traversal to prevent stack overflow.
    private let snapshotMaxDepth = 60

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Handles incoming dumpUI requests.
    ///
    /// - Parameter request: The HTTP request containing dump parameters.
    /// - Returns: HTTP response with JSON view hierarchy or error.
    func handleRequest(_ request: FlyingFox.HTTPRequest) async throws
        -> HTTPResponse
    {
        guard
            let requestBody = try? await JSONDecoder().decode(
                DumpUIRequest.self,
                from: request.bodyData
            )
        else {
            return ServerError(
                type: .precondition,
                message: "incorrect request body provided"
            ).httpResponse
        }

        do {
            let foregroundApp = RunningApp.getForegroundApp()
            guard let foregroundApp = foregroundApp else {
                NSLog(
                    "No foreground app found returning springboard app hierarchy"
                )
                let springboardHierarchy = try elementHierarchy(
                    xcuiElement: springboardApplication
                )
                let springBoardViewHierarchy = ViewHierarchy.init(
                    axElement: springboardHierarchy,
                    depth: springboardHierarchy.depth()
                )
                let body = try JSONEncoder().encode(springBoardViewHierarchy)
                return HTTPResponse(statusCode: .ok, body: body)
            }
            NSLog("[Start] View hierarchy snapshot for \(foregroundApp)")
            let appViewHierarchy = try logger.measure(
                message: "View hierarchy snapshot for \(foregroundApp)"
            ) {
                try getAppViewHierarchy(
                    foregroundApp: foregroundApp,
                    excludeKeyboardElements: requestBody.excludeKeyboardElements
                )
            }
            let viewHierarchy = ViewHierarchy.init(
                axElement: appViewHierarchy,
                depth: appViewHierarchy.depth()
            )

            NSLog("[Done] View hierarchy snapshot for \(foregroundApp) ")
            let body = try JSONEncoder().encode(viewHierarchy)
            return HTTPResponse(statusCode: .ok, body: body)
        } catch let error as ServerError {
            NSLog("AppError in handleRequest, Error:\(error)")
            return error.httpResponse
        } catch let error {
            NSLog("Error in handleRequest, Error:\(error)")
            return ServerError(
                message:
                    "Snapshot failure while getting view hierarchy. Error: \(error.localizedDescription)"
            ).httpResponse
        }
    }

    /// Builds the complete view hierarchy for the foreground application.
    ///
    /// This method assembles the view hierarchy from multiple sources:
    /// - Main application view tree
    /// - Status bar elements
    /// - Safari WebView content (iOS 26+)
    ///
    /// - Parameters:
    ///   - foregroundApp: The application to capture.
    ///   - excludeKeyboardElements: Whether to filter out keyboard UI.
    /// - Returns: A composite `AXElement` containing the full hierarchy.
    func getAppViewHierarchy(
        foregroundApp: XCUIApplication,
        excludeKeyboardElements: Bool
    ) throws -> AXElement {
        SystemPermissionManager.handleSystemPermissionAlertIfNeeded(
            foregroundApp: foregroundApp
        )
        let appHierarchy = try getHierarchyWithFallback(foregroundApp)

        let statusBars =
            logger.measure(message: "Fetch status bar hierarchy") {
                fullStatusBars(springboardApplication)
            } ?? []

        // Fetch Safari WebView hierarchy for iOS 26+ (runs in separate SafariViewService process)
        let safariWebViewHierarchy = logger.measure(
            message: "Fetch Safari WebView hierarchy"
        ) {
            getSafariWebViewHierarchy()
        }

        let deviceFrame = springboardApplication.frame
        let deviceAxFrame = [
            "X": Double(deviceFrame.minX),
            "Y": Double(deviceFrame.minY),
            "Width": Double(deviceFrame.width),
            "Height": Double(deviceFrame.height),
        ]
        let appFrame = appHierarchy.frame

        if deviceAxFrame != appFrame {
            guard
                let deviceWidth = deviceAxFrame["Width"], deviceWidth > 0,
                let deviceHeight = deviceAxFrame["Height"], deviceHeight > 0,
                let appWidth = appFrame["Width"], appWidth > 0,
                let appHeight = appFrame["Height"], appHeight > 0
            else {
                return AXElement(
                    children: [
                        appHierarchy, AXElement(children: statusBars),
                        safariWebViewHierarchy,
                    ].compactMap { $0 }
                )
            }

            let offsetX = deviceWidth - appWidth
            let offsetY = deviceHeight - appHeight
            let offset = WindowOffset(offsetX: offsetX, offsetY: offsetY)

            NSLog("Adjusting view hierarchy with offset: \(offset)")

            let adjustedAppHierarchy = expandElementSizes(
                appHierarchy,
                offset: offset
            )

            return AXElement(
                children: [
                    adjustedAppHierarchy, AXElement(children: statusBars),
                    safariWebViewHierarchy,
                ].compactMap { $0 }
            )
        } else {
            return AXElement(
                children: [
                    appHierarchy, AXElement(children: statusBars),
                    safariWebViewHierarchy,
                ].compactMap { $0 }
            )
        }
    }

    func expandElementSizes(_ element: AXElement, offset: WindowOffset)
        -> AXElement
    {
        let adjustedFrame: AXFrame = [
            "X": (element.frame["X"] ?? 0) + offset.offsetX,
            "Y": (element.frame["Y"] ?? 0) + offset.offsetY,
            "Width": element.frame["Width"] ?? 0,
            "Height": element.frame["Height"] ?? 0,
        ]
        let adjustedChildren =
            element.children?.map { expandElementSizes($0, offset: offset) }
            ?? []

        return AXElement(
            identifier: element.identifier,
            frame: adjustedFrame,
            value: element.value,
            title: element.title,
            label: element.label,
            elementType: element.elementType,
            enabled: element.enabled,
            horizontalSizeClass: element.horizontalSizeClass,
            verticalSizeClass: element.verticalSizeClass,
            placeholderValue: element.placeholderValue,
            selected: element.selected,
            hasFocus: element.hasFocus,
            displayID: element.displayID,
            windowContextID: element.windowContextID,
            children: adjustedChildren
        )
    }

    /// Retrieves the view hierarchy with automatic fallback for deep hierarchies.
    ///
    /// When encountering `kAXErrorIllegalArgument` errors (common with deep view trees),
    /// this method applies a fallback strategy by limiting snapshot depth and recursively
    /// processing child elements.
    ///
    /// - Parameter element: The XCUIElement to snapshot.
    /// - Returns: The `AXElement` representation of the hierarchy.
    /// - Throws: `ServerError` if snapshot fails due to timeout or other unrecoverable errors.
    func getHierarchyWithFallback(_ element: XCUIElement) throws -> AXElement {
        logger.info("Starting getHierarchyWithFallback for element.")

        do {
            var hierarchy = try elementHierarchy(xcuiElement: element)
            logger.info("Successfully retrieved element hierarchy.")

            if hierarchy.depth() < snapshotMaxDepth {
                return hierarchy
            }
            let count = try element.snapshot().children.count
            var children: [AXElement] = []
            for i in 0..<count {
                let element = element.descendants(matching: .other).element(
                    boundBy: i
                ).firstMatch
                children.append(try getHierarchyWithFallback(element))
            }
            hierarchy.children = children
            return hierarchy
        } catch let error {
            guard isIllegalArgumentError(error) else {
                NSLog(
                    "Snapshot failure, cannot return view hierarchy due to \(error)"
                )
                if let nsError = error as NSError?,
                    nsError.domain == "com.apple.dt.XCTest.XCTFuture",
                    nsError.code == 1000,
                    nsError.localizedDescription.contains(
                        "Timed out while evaluating UI query"
                    )
                {
                    throw ServerError(
                        type: .timeout,
                        message: error.localizedDescription
                    )
                } else if let nsError = error as NSError?,
                    nsError.domain
                        == "com.apple.dt.xctest.automation-support.error",
                    nsError.code == 6,
                    nsError.localizedDescription.contains(
                        "Unable to perform work on main run loop, process main thread busy for"
                    )
                {
                    throw ServerError(
                        type: .timeout,
                        message: nsError.localizedDescription
                    )
                } else {
                    throw ServerError(message: error.localizedDescription)
                }
            }

            NSLog("Snapshot failure, getting recovery element for fallback")
            AXClientSwizzler.overwriteDefaultParameters["maxDepth"] =
                snapshotMaxDepth
            // In apps with bigger view hierarchys, calling
            // `XCUIApplication().snapshot().dictionaryRepresentation` or `XCUIApplication().allElementsBoundByIndex`
            // throws "Error kAXErrorIllegalArgument getting snapshot for element <AXUIElementRef 0x6000025eb660>"
            // We recover by selecting the first child of the app element,
            // which should be the window, and continue from there.

            let recoveryElement = try findRecoveryElement(
                element.children(matching: .any).firstMatch
            )
            let hierarchy = try getHierarchyWithFallback(recoveryElement)

            // When the application element is skipped, try to fetch
            // the keyboard, alert and other custom element hierarchies separately.
            if let element = element as? XCUIApplication {
                let keyboard = logger.measure(
                    message: "Fetch keyboard hierarchy"
                ) {
                    keyboardHierarchy(element)
                }

                let alerts = logger.measure(message: "Fetch alert hierarchy") {
                    fullScreenAlertHierarchy(element)
                }

                let other = try logger.measure(
                    message: "Fetch other custom element from window"
                ) {
                    try customWindowElements(element)
                }
                return AXElement(
                    children: [
                        other,
                        keyboard,
                        alerts,
                        hierarchy,
                    ].compactMap { $0 }
                )
            }

            return hierarchy
        }
    }

    private func isIllegalArgumentError(_ error: Error) -> Bool {
        error.localizedDescription.contains(
            "Error kAXErrorIllegalArgument getting snapshot for element"
        )
    }

    private func keyboardHierarchy(_ element: XCUIApplication) -> AXElement? {
        guard element.keyboards.firstMatch.exists else {
            return nil
        }

        let keyboard = element.keyboards.firstMatch
        return try? elementHierarchy(xcuiElement: keyboard)
    }

    private func customWindowElements(_ element: XCUIApplication) throws
        -> AXElement?
    {
        let windowElement = element.children(matching: .any).firstMatch
        if try windowElement.snapshot().children.count > 1 {
            return nil
        }
        return try? elementHierarchy(xcuiElement: windowElement)
    }

    func fullScreenAlertHierarchy(_ element: XCUIApplication) -> AXElement? {
        guard element.alerts.firstMatch.exists else {
            return nil
        }

        let alert = element.alerts.firstMatch
        return try? elementHierarchy(xcuiElement: alert)
    }

    func fullStatusBars(_ element: XCUIApplication) -> [AXElement]? {
        guard element.statusBars.firstMatch.exists else {
            return nil
        }

        let snapshots = try? element.statusBars.allElementsBoundByIndex
            .compactMap { (statusBar) in
                try elementHierarchy(xcuiElement: statusBar)
            }

        return snapshots
    }

    /// Fetches the Safari WebView hierarchy for iOS 26+ where SFSafariViewController
    /// runs in a separate process (com.apple.SafariViewService).
    /// Returns nil if not on iOS 26+, Safari service is not running, or no webviews exist.
    private func getSafariWebViewHierarchy() -> AXElement? {
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        guard systemVersion.majorVersion >= 26 else {
            return nil
        }

        let safariWebService = XCUIApplication(
            bundleIdentifier: "com.apple.SafariViewService"
        )

        let isRunning =
            safariWebService.state == .runningForeground
            || safariWebService.state == .runningBackground
        guard isRunning else {
            return nil
        }

        let webViewCount = safariWebService.webViews.count
        guard webViewCount > 0 else {
            return nil
        }

        NSLog(
            "[Start] Fetching Safari WebView hierarchy (\(webViewCount) webview(s) detected)"
        )

        do {
            AXClientSwizzler.overwriteDefaultParameters["maxDepth"] =
                snapshotMaxDepth
            let safariHierarchy = try elementHierarchy(
                xcuiElement: safariWebService
            )
            NSLog("[Done] Safari WebView hierarchy fetched successfully")
            return safariHierarchy
        } catch {
            NSLog(
                "[Error] Failed to fetch Safari WebView hierarchy: \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func findRecoveryElement(_ element: XCUIElement) throws
        -> XCUIElement
    {
        if try element.snapshot().children.count > 1 {
            return element
        }
        let firstOtherElement = element.children(matching: .other).firstMatch
        if firstOtherElement.exists {
            return try findRecoveryElement(firstOtherElement)
        } else {
            return element
        }
    }

    private func elementHierarchy(xcuiElement: XCUIElement) throws -> AXElement
    {
        let snapshotDictionary = try xcuiElement.snapshot()
            .dictionaryRepresentation
        return AXElement(snapshotDictionary)
    }
}
