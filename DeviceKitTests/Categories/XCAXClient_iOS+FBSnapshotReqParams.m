/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * @file XCAXClient_iOS+FBSnapshotReqParams.m
 * @brief Implementation of snapshot parameter customization via method
 * swizzling.
 *
 * This file implements the FBSnapshotReqParams category on XCAXClient_iOS,
 * enabling custom parameters for accessibility element snapshots.
 *
 * ## Method Swizzling
 *
 * At load time (when `snapshotKeyHonorModalViews=false` environment variable is
 * set), this category swizzles two methods:
 * - `XCAXClient_iOS.defaultParameters` - to merge custom parameters
 * - `XCTElementQuery.snapshotParameters` - to capture additional parameters
 *
 * ## Available Parameters
 *
 * The following parameters can be customized (with XCTest defaults shown):
 * - `maxChildren`: 2147483647 (INT_MAX)
 * - `traverseFromParentsToChildren`: YES
 * - `maxArrayCount`: 2147483647 (INT_MAX)
 * - `snapshotKeyHonorModalViews`: NO
 * - `maxDepth`: 2147483647 (INT_MAX)
 *
 * ## Usage
 *
 * Set the `snapshotKeyHonorModalViews` environment variable to "false" to
 * enable this swizzling. This makes elements behind modal dialogs visible in
 * snapshots.
 */

#import "XCAXClient_iOS+FBSnapshotReqParams.h"

#import <objc/runtime.h>

#pragma mark - Constants

/**
 * Key constant for the maximum snapshot depth parameter.
 */
NSString *const FBSnapshotMaxDepthKey = @"maxDepth";

#pragma mark - Static Storage

/** Pointer to original defaultParameters implementation. */
static id (*original_defaultParameters)(id, SEL);

/** Pointer to original snapshotParameters implementation. */
static id (*original_snapshotParameters)(id, SEL);

/** Cache of original default parameters from XCAXClient_iOS. */
static NSDictionary *defaultRequestParameters;

/** Additional parameters captured from XCTElementQuery. */
static NSDictionary *defaultAdditionalRequestParameters;

/** Custom parameters set via FBSetCustomParameterForElementSnapshot. */
static NSMutableDictionary *customRequestParameters;

#pragma mark - Public Functions

void FBSetCustomParameterForElementSnapshot(NSString *name, id value) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      customRequestParameters = [NSMutableDictionary new];
    });
    customRequestParameters[name] = value;
}

id FBGetCustomParameterForElementSnapshot(NSString *name) {
    return customRequestParameters[name];
}

#pragma mark - Swizzled Implementations

/**
 * Swizzled implementation for XCAXClient_iOS.defaultParameters.
 *
 * Merges the original default parameters with additional parameters
 * from XCTElementQuery and any custom parameters set by the user.
 *
 * @param self The XCAXClient_iOS instance.
 * @param _cmd The selector being called.
 * @return Dictionary of merged snapshot parameters.
 */
static id swizzledDefaultParameters(id self, SEL _cmd) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      defaultRequestParameters = original_defaultParameters(self, _cmd);
    });
    NSMutableDictionary *result =
        [NSMutableDictionary dictionaryWithDictionary:defaultRequestParameters];
    [result addEntriesFromDictionary:defaultAdditionalRequestParameters ?: @{}];
    [result addEntriesFromDictionary:customRequestParameters ?: @{}];
    return result.copy;
}

/**
 * Swizzled implementation for XCTElementQuery.snapshotParameters.
 *
 * Captures the additional snapshot parameters used by element queries
 * and stores them for merging in defaultParameters.
 *
 * @param self The XCTElementQuery instance.
 * @param _cmd The selector being called.
 * @return The original snapshot parameters.
 */
static id swizzledSnapshotParameters(id self, SEL _cmd) {
    NSDictionary *result = original_snapshotParameters(self, _cmd);
    defaultAdditionalRequestParameters = result;
    return result;
}

#pragma mark - Category Implementation

@implementation XCAXClient_iOS (FBSnapshotReqParams)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"
#pragma clang diagnostic ignored "-Wcast-function-type-strict"

/**
 * Performs method swizzling at class load time.
 *
 * Checks for the `snapshotKeyHonorModalViews` environment variable.
 * If set to "false", swizzles the defaultParameters and snapshotParameters
 * methods to enable visibility of elements behind modal dialogs.
 */
+ (void)load {
    // snapshotKeyHonorModalViews to false to make modals and dialogs visible
    // that are invisible otherwise
    NSString *snapshotKeyHonorModalViewsKey = [[NSProcessInfo processInfo]
        environment][@"snapshotKeyHonorModalViews"];
    NSLog(@"snapshotKeyHonorModalViews configured to value: %@",
          snapshotKeyHonorModalViewsKey);
    if ([snapshotKeyHonorModalViewsKey isEqualToString:@"false"]) {
        NSLog(@"Disabling snapshotKeyHonorModalViews to make elements behind "
              @"modals visible");
        FBSetCustomParameterForElementSnapshot(@"snapshotKeyHonorModalViews",
                                               @0);

        Method original_defaultParametersMethod =
            class_getInstanceMethod(self.class, @selector(defaultParameters));
        IMP swizzledDefaultParametersImp = (IMP)swizzledDefaultParameters;
        original_defaultParameters = (id(*)(id, SEL))method_setImplementation(
            original_defaultParametersMethod, swizzledDefaultParametersImp);

        Method original_snapshotParametersMethod = class_getInstanceMethod(
            NSClassFromString(@"XCTElementQuery"),
            NSSelectorFromString(@"snapshotParameters"));
        IMP swizzledSnapshotParametersImp = (IMP)swizzledSnapshotParameters;
        original_snapshotParameters = (id(*)(id, SEL))method_setImplementation(
            original_snapshotParametersMethod, swizzledSnapshotParametersImp);
    }
}

#pragma clang diagnostic pop

@end
