/**
 * @file devicekit-iosUITests-Bridging-Header.h
 * @brief Bridging header exposing Objective-C APIs to Swift.
 *
 * This file imports Objective-C headers that need to be accessible from
 * Swift code in the devicekit-iosUITests target. These include:
 *
 * - XCUIApplication categories for quiescence and helper methods
 * - Accessibility client proxy for app enumeration
 * - Snapshot parameter customization
 *
 * @note Headers imported here are automatically available in Swift without
 *       explicit import statements.
 */

// MARK: - XCUIApplication Categories

/** Quiescence control for application idle state management. */
#import "XCUIApplication+FBQuiescence.h"

/** Helper methods for querying active applications. */
#import "XCUIApplication+Helper.h"

// MARK: - Accessibility Client

/** Proxy for accessing XCTest's accessibility interface. */
#import "AXClientProxy.h"

// MARK: - Snapshot Configuration

/** Custom snapshot parameters (maxDepth, snapshotKeyHonorModalViews). */
#import "XCAXClient_iOS+FBSnapshotReqParams.h"

// MARK: - Fast Screenshot

/** Fast screenshot capture using XCTest daemon proxy. */
#import "FBScreenshot.h"
