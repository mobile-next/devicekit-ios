/**
 * @file XCUIApplication+Helper.h
 * @brief Category providing helper methods for XCUIApplication.
 *
 * Extends XCUIApplication with methods for retrieving information
 * about active applications via the accessibility interface.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @category XCUIApplication (Helper)
 * @brief Helper methods for querying active application information.
 *
 * This category provides methods to retrieve information about currently
 * running applications, including their process IDs and bundle identifiers.
 *
 * @code
 * NSArray *apps = [XCUIApplication activeAppsInfo];
 * for (NSDictionary *appInfo in apps) {
 *     NSNumber *pid = appInfo[@"pid"];
 *     NSString *bundleId = appInfo[@"bundleId"];
 *     NSLog(@"App: %@ (PID: %@)", bundleId, pid);
 * }
 * @endcode
 */
@interface XCUIApplication (Helper)

/**
 * Returns information about all currently active (running) applications.
 *
 * Queries the accessibility interface for active applications and
 * retrieves their bundle identifiers via the test runner daemon.
 *
 * @return Array of dictionaries, each containing:
 *         - @"pid": NSNumber with the process identifier
 *         - @"bundleId": NSString with the bundle identifier (or "unknowBundleId" if unavailable)
 */
+ (NSArray<NSDictionary<NSString *, id> *> *)activeAppsInfo;

@end

NS_ASSUME_NONNULL_END
