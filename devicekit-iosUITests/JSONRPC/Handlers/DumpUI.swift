import os

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

// MARK: - DumpUI Method Handler

/// JSON-RPC handler for the `dumpUI` method.
///
/// Captures the complete UI view hierarchy.
///
/// ## Parameters
/// ```json
/// {
///   "appIds": [],
///   "excludeKeyboardElements": false
/// }
/// ```
///
/// ## Result
/// Returns the view hierarchy as a nested JSON object.
@MainActor
struct DumpUIMethodHandler: RPCMethodHandler {
    static let methodName = "dumpUI"

    private let springboardApplication = XCUIApplication(
        bundleIdentifier: "com.apple.springboard"
    )
    private let snapshotMaxDepth = 60

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        guard let params = params else {
            throw RPCMethodError.invalidParams("Missing parameters for dumpUI method")
        }

        let paramsData: Data
        do {
            paramsData = try params.toData()
        } catch {
            throw RPCMethodError.invalidParams("Failed to serialize params: \(error.localizedDescription)")
        }

        let request: DumpUIRequest
        do {
            request = try JSONDecoder().decode(DumpUIRequest.self, from: paramsData)
        } catch {
            throw RPCMethodError.invalidParams("Invalid dumpUI parameters: \(error.localizedDescription)")
        }

        do {
            let foregroundApp = RunningApp.getForegroundApp()
            guard let foregroundApp = foregroundApp else {
                NSLog("No foreground app found returning springboard app hierarchy")
                let springboardHierarchy = try elementHierarchy(xcuiElement: springboardApplication)
                let viewHierarchy = ViewHierarchy(
                    axElement: springboardHierarchy,
                    depth: springboardHierarchy.depth()
                )
                return try JSONValue.from(viewHierarchy)
            }

            NSLog("[Start] View hierarchy snapshot for \(foregroundApp)")
            let appViewHierarchy = try logger.measure(
                message: "View hierarchy snapshot for \(foregroundApp)"
            ) {
                try getAppViewHierarchy(
                    foregroundApp: foregroundApp,
                    excludeKeyboardElements: request.excludeKeyboardElements
                )
            }
            let viewHierarchy = ViewHierarchy(
                axElement: appViewHierarchy,
                depth: appViewHierarchy.depth()
            )

            NSLog("[Done] View hierarchy snapshot for \(foregroundApp)")
            return try JSONValue.from(viewHierarchy)
        } catch let error as RPCMethodError {
            throw error
        } catch let error as NSError {
            if error.domain == "com.apple.dt.XCTest.XCTFuture",
               error.code == 1000,
               error.localizedDescription.contains("Timed out while evaluating UI query") {
                throw RPCMethodError.timeout(error.localizedDescription)
            } else if error.domain == "com.apple.dt.xctest.automation-support.error",
                      error.code == 6,
                      error.localizedDescription.contains("Unable to perform work on main run loop") {
                throw RPCMethodError.timeout(error.localizedDescription)
            } else {
                throw RPCMethodError.internalError("Snapshot failure: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helper Methods

    private func getAppViewHierarchy(
        foregroundApp: XCUIApplication,
        excludeKeyboardElements: Bool
    ) throws -> AXElement {
        SystemPermissionManager.handleSystemPermissionAlertIfNeeded(foregroundApp: foregroundApp)
        let appHierarchy = try getHierarchyWithFallback(foregroundApp)

        let statusBars = logger.measure(message: "Fetch status bar hierarchy") {
            fullStatusBars(springboardApplication)
        } ?? []

        let safariWebViewHierarchy = logger.measure(message: "Fetch Safari WebView hierarchy") {
            getSafariWebViewHierarchy()
        }

        let deviceFrame = springboardApplication.frame
        let deviceAxFrame: AXFrame = [
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
                    children: [appHierarchy, AXElement(children: statusBars), safariWebViewHierarchy].compactMap { $0 }
                )
            }

            let offsetX = deviceWidth - appWidth
            let offsetY = deviceHeight - appHeight
            let offset = WindowOffset(offsetX: offsetX, offsetY: offsetY)

            NSLog("Adjusting view hierarchy with offset: \(offset)")

            let adjustedAppHierarchy = expandElementSizes(appHierarchy, offset: offset)

            return AXElement(
                children: [adjustedAppHierarchy, AXElement(children: statusBars), safariWebViewHierarchy].compactMap { $0 }
            )
        } else {
            return AXElement(
                children: [appHierarchy, AXElement(children: statusBars), safariWebViewHierarchy].compactMap { $0 }
            )
        }
    }

    private func expandElementSizes(_ element: AXElement, offset: WindowOffset) -> AXElement {
        let adjustedFrame: AXFrame = [
            "X": (element.frame["X"] ?? 0) + offset.offsetX,
            "Y": (element.frame["Y"] ?? 0) + offset.offsetY,
            "Width": element.frame["Width"] ?? 0,
            "Height": element.frame["Height"] ?? 0,
        ]
        let adjustedChildren = element.children?.map { expandElementSizes($0, offset: offset) } ?? []

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

    private func getHierarchyWithFallback(_ element: XCUIElement) throws -> AXElement {
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
                let element = element.descendants(matching: .other).element(boundBy: i).firstMatch
                children.append(try getHierarchyWithFallback(element))
            }
            hierarchy.children = children
            return hierarchy
        } catch let error {
            guard isIllegalArgumentError(error) else {
                throw error
            }

            NSLog("Snapshot failure, getting recovery element for fallback")
            AXClientSwizzler.overwriteDefaultParameters["maxDepth"] = snapshotMaxDepth

            let recoveryElement = try findRecoveryElement(element.children(matching: .any).firstMatch)
            let hierarchy = try getHierarchyWithFallback(recoveryElement)

            if let element = element as? XCUIApplication {
                let keyboard = logger.measure(message: "Fetch keyboard hierarchy") {
                    keyboardHierarchy(element)
                }

                let alerts = logger.measure(message: "Fetch alert hierarchy") {
                    fullScreenAlertHierarchy(element)
                }

                let other = try logger.measure(message: "Fetch other custom element from window") {
                    try customWindowElements(element)
                }
                return AXElement(children: [other, keyboard, alerts, hierarchy].compactMap { $0 })
            }

            return hierarchy
        }
    }

    private func isIllegalArgumentError(_ error: Error) -> Bool {
        error.localizedDescription.contains("Error kAXErrorIllegalArgument getting snapshot for element")
    }

    private func keyboardHierarchy(_ element: XCUIApplication) -> AXElement? {
        guard element.keyboards.firstMatch.exists else { return nil }
        let keyboard = element.keyboards.firstMatch
        return try? elementHierarchy(xcuiElement: keyboard)
    }

    private func customWindowElements(_ element: XCUIApplication) throws -> AXElement? {
        let windowElement = element.children(matching: .any).firstMatch
        if try windowElement.snapshot().children.count > 1 {
            return nil
        }
        return try? elementHierarchy(xcuiElement: windowElement)
    }

    private func fullScreenAlertHierarchy(_ element: XCUIApplication) -> AXElement? {
        guard element.alerts.firstMatch.exists else { return nil }
        let alert = element.alerts.firstMatch
        return try? elementHierarchy(xcuiElement: alert)
    }

    private func fullStatusBars(_ element: XCUIApplication) -> [AXElement]? {
        guard element.statusBars.firstMatch.exists else { return nil }
        return try? element.statusBars.allElementsBoundByIndex.compactMap { statusBar in
            try elementHierarchy(xcuiElement: statusBar)
        }
    }

    private func getSafariWebViewHierarchy() -> AXElement? {
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        guard systemVersion.majorVersion >= 26 else { return nil }

        let safariWebService = XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")
        let isRunning = safariWebService.state == .runningForeground || safariWebService.state == .runningBackground
        guard isRunning else { return nil }

        let webViewCount = safariWebService.webViews.count
        guard webViewCount > 0 else { return nil }

        NSLog("[Start] Fetching Safari WebView hierarchy (\(webViewCount) webview(s) detected)")

        do {
            AXClientSwizzler.overwriteDefaultParameters["maxDepth"] = snapshotMaxDepth
            let safariHierarchy = try elementHierarchy(xcuiElement: safariWebService)
            NSLog("[Done] Safari WebView hierarchy fetched successfully")
            return safariHierarchy
        } catch {
            NSLog("[Error] Failed to fetch Safari WebView hierarchy: \(error.localizedDescription)")
            return nil
        }
    }

    private func findRecoveryElement(_ element: XCUIElement) throws -> XCUIElement {
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

    private func elementHierarchy(xcuiElement: XCUIElement) throws -> AXElement {
        let snapshotDictionary = try xcuiElement.snapshot().dictionaryRepresentation
        return AXElement(snapshotDictionary)
    }
}
