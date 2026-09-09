/**
 * @file AXClientProxy.h
 * @brief Proxy for accessing XCTest's accessibility client interface.
 *
 * Provides a singleton wrapper around XCUIDevice's accessibility interface,
 * enabling access to active applications and default snapshot parameters.
 */

#import "XCAccessibilityElement.h"
#import <XCTest/XCTest.h>

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

/**
 * Returns the class name of the view controller presenting the current screen
 * of an application, or nil when the accessibility server reports none.
 *
 * This is the iOS counterpart of the focused activity on Android. The value
 * comes from the accessibility snapshot: elements that host a view controller
 * carry its class name as an extra attribute. The deepest one wins, so a
 * pushed or presented controller is reported rather than the root.
 *
 * @param pid Process id of the application to inspect.
 * @return The view controller class name, or nil when there is none to report.
 */
- (nullable NSString *)viewControllerClassNameForProcessIdentifier:(int)pid
    NS_SWIFT_NAME(viewControllerClassName(forProcessIdentifier:));

@end

NS_ASSUME_NONNULL_END
