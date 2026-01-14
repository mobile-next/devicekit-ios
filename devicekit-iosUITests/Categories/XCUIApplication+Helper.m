/**
 * @file XCUIApplication+Helper.m
 * @brief Implementation of XCUIApplication helper category.
 */

#import "XCUIApplication+Helper.h"
#import "AXClientProxy.h"
#import "FBLogger.h"
#import "XCTestDaemonsProxy.h"
#import "XCAccessibilityElement.h"
#import "XCTestManager_ManagerInterface-Protocol.h"

@implementation XCUIApplication (Helper)

#pragma mark - Private Methods

/**
 * Converts accessibility elements to app info dictionaries.
 *
 * For each accessibility element, retrieves the bundle ID from the
 * test runner daemon using the process identifier.
 *
 * @param axElements Array of accessibility elements representing apps.
 * @return Array of dictionaries with "pid" and "bundleId" keys.
 */
+ (NSArray<NSDictionary<NSString *, id> *> *)appsInfoWithAxElements:(NSArray<id<XCAccessibilityElement>> *)axElements
{
    NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
    id<XCTestManager_ManagerInterface> proxy = [XCTestDaemonsProxy testRunnerProxy];

    for (id<XCAccessibilityElement> axElement in axElements) {
        NSMutableDictionary<NSString *, id> *appInfo = [NSMutableDictionary dictionary];
        pid_t pid = axElement.processIdentifier;
        appInfo[@"pid"] = @(pid);

        // Asynchronously request bundle ID with 1 second timeout
        __block NSString *bundleId = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [proxy _XCT_requestBundleIDForPID:pid
                                    reply:^(NSString *bundleID, NSError *error) {
            if (nil == error) {
                bundleId = bundleID;
            } else {
                [FBLogger logFmt:@"Cannot request the bundle ID for process ID %@: %@", @(pid), error.description];
            }
            dispatch_semaphore_signal(sem);
        }];
        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));

        appInfo[@"bundleId"] = bundleId ?: @"unknowBundleId";
        [result addObject:appInfo.copy];
    }
    return result.copy;
}

#pragma mark - Public Methods

+ (NSArray<NSDictionary<NSString *, id> *> *)activeAppsInfo
{
    return [self appsInfoWithAxElements:[AXClientProxy.sharedClient activeApplications]];
}

@end
