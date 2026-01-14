/**
 * @file AXClientProxy.h
 * @brief Proxy for accessing XCTest's accessibility client interface.
 *
 * Provides a singleton wrapper around XCUIDevice's accessibility interface,
 * enabling access to active applications and default snapshot parameters.
 */

#import <XCTest/XCTest.h>
#import "XCAccessibilityElement.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @class AXClientProxy
 * @brief Singleton proxy for XCTest's accessibility client (XCAXClient_iOS).
 *
 * This class wraps the private accessibility interface obtained from
 * XCUIDevice.sharedDevice.accessibilityInterface, providing methods to:
 * - Retrieve the list of currently active (running) applications
 * - Access default parameters used for accessibility snapshots
 *
 * @note Uses XCUIDevice private API via reflection.
 *
 * @code
 * // Get active applications
 * NSArray *apps = [[AXClientProxy sharedClient] activeApplications];
 *
 * // Get default snapshot parameters
 * NSDictionary *params = [[AXClientProxy sharedClient] defaultParameters];
 * @endcode
 */
@interface AXClientProxy : NSObject

/**
 * Returns the shared singleton instance.
 *
 * The instance is created lazily on first access and caches
 * the accessibility interface from XCUIDevice.
 *
 * @return The shared AXClientProxy instance.
 */
+ (instancetype)sharedClient;

/**
 * Returns an array of currently active (running) applications.
 *
 * Each element conforms to XCAccessibilityElement protocol and
 * contains process information for a running application.
 *
 * @return Array of accessibility elements representing active apps.
 */
- (NSArray<id<XCAccessibilityElement>> *)activeApplications;

/**
 * Returns the default parameters used for accessibility snapshots.
 *
 * These parameters control snapshot behavior such as maxDepth,
 * maxChildren, and traversal options.
 *
 * @return Dictionary of default snapshot parameters.
 */
- (NSDictionary *)defaultParameters;

@end

NS_ASSUME_NONNULL_END
