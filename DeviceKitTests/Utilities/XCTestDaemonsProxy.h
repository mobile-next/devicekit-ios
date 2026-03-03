/**
 * @file XCTestDaemonsProxy.h
 * @brief Proxy for accessing XCTest's test runner daemon session.
 *
 * Provides access to the XCTestManager_ManagerInterface protocol for
 * communicating with the XCTest daemon service.
 */

#import <XCTest/XCTest.h>

#import "XCSynthesizedEventRecord.h"

NS_ASSUME_NONNULL_BEGIN

@protocol XCTestManager_ManagerInterface;

/**
 * @class XCTestDaemonsProxy
 * @brief Singleton proxy for XCTest's daemon manager interface.
 *
 * This class provides access to the test runner's daemon proxy, which enables
 * communication with XCTest's background daemon service for operations like:
 * - Requesting bundle IDs for process IDs
 * - Event synthesis
 * - Application state management
 *
 * @note Uses XCTRunnerDaemonSession private API.
 *
 * @code
 * id<XCTestManager_ManagerInterface> proxy = [XCTestDaemonsProxy
 * testRunnerProxy]; [proxy _XCT_requestBundleIDForPID:pid reply:^(NSString
 * *bundleID, NSError *error) {
 *     // Handle response
 * }];
 * @endcode
 */
@interface XCTestDaemonsProxy : NSObject

/**
 * Returns the shared test runner daemon proxy.
 *
 * The proxy is retrieved lazily from XCTRunnerDaemonSession.sharedSession
 * and cached for subsequent calls.
 *
 * @return The daemon proxy conforming to XCTestManager_ManagerInterface.
 */
+ (id<XCTestManager_ManagerInterface>)testRunnerProxy;

@end

NS_ASSUME_NONNULL_END
