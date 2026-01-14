/**
 * @file XCTestDaemonsProxy.m
 * @brief Implementation of XCTestDaemonsProxy singleton.
 */

#import "XCTestDaemonsProxy.h"
#import "FBLogger.h"
#import "XCTRunnerDaemonSession.h"

@implementation XCTestDaemonsProxy

#pragma mark - Public Methods

+ (id<XCTestManager_ManagerInterface>)testRunnerProxy {
    static id<XCTestManager_ManagerInterface> proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      [FBLogger logFmt:@"Using singleton test manager"];
      proxy = [self.class retrieveTestRunnerProxy];
    });
    return proxy;
}

#pragma mark - Private Methods

/**
 * Retrieves the daemon proxy from XCTRunnerDaemonSession.
 * @return The daemon proxy instance.
 */
+ (id<XCTestManager_ManagerInterface>)retrieveTestRunnerProxy {
    return ((XCTRunnerDaemonSession *)[XCTRunnerDaemonSession sharedSession])
        .daemonProxy;
}

@end
