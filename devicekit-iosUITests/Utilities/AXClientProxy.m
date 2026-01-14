/**
 * @file AXClientProxy.m
 * @brief Implementation of AXClientProxy singleton.
 */

#import "AXClientProxy.h"
#import "XCAccessibilityElement.h"
#import "XCUIDevice.h"

/// Cached reference to the accessibility client interface (XCAXClient_iOS).
static id AXClient = nil;

@implementation AXClientProxy

#pragma mark - Singleton

+ (instancetype)sharedClient
{
    static AXClientProxy *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        // Access private accessibilityInterface property from XCUIDevice
        AXClient = [XCUIDevice.sharedDevice accessibilityInterface];
    });
    return instance;
}

#pragma mark - Public Methods

- (NSArray<id<XCAccessibilityElement>> *)activeApplications
{
    return [AXClient activeApplications];
}

- (NSDictionary *)defaultParameters {
    return [AXClient defaultParameters];
}

@end
