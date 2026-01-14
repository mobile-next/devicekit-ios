/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * @file XCUIApplicationProcess+FBQuiescence.m
 * @brief Implementation of process-level quiescence control with method swizzling.
 *
 * This file implements the FBQuiescence category on XCUIApplicationProcess,
 * providing custom quiescence handling through Objective-C runtime method swizzling.
 *
 * ## Method Swizzling
 *
 * At load time, this category swizzles one of two quiescence methods depending
 * on the iOS version:
 * - `waitForQuiescenceIncludingAnimationsIdle:` (newer iOS versions)
 * - `waitForQuiescenceIncludingAnimationsIdle:isPreEvent:` (older iOS versions)
 *
 * The swizzled implementations:
 * 1. Check if quiescence is enabled via `fb_shouldWaitForQuiescence`
 * 2. Apply custom timeout from `FBConfiguration.waitForIdleTimeout`
 * 3. Call the original implementation with the configured timeout
 *
 * ## Associated Objects
 *
 * The `fb_shouldWaitForQuiescence` property uses Objective-C associated objects
 * to store state on the XCUIApplicationProcess instance, allowing per-process
 * quiescence control without subclassing.
 */

#import "XCUIApplicationProcess+FBQuiescence.h"

#import <objc/runtime.h>

#import "FBConfiguration.h"
#import "FBLogger.h"

#pragma mark - Original Method Pointers

/**
 * Pointer to the original waitForQuiescenceIncludingAnimationsIdle: implementation.
 * Used to call the original behavior after custom timeout configuration.
 */
static void (*original_waitForQuiescenceIncludingAnimationsIdle)(id, SEL, BOOL);

/**
 * Pointer to the original waitForQuiescenceIncludingAnimationsIdle:isPreEvent: implementation.
 * Used on older iOS versions with the two-parameter quiescence method.
 */
static void (*original_waitForQuiescenceIncludingAnimationsIdlePreEvent)(id, SEL, BOOL, BOOL);

#pragma mark - Swizzled Implementations

/**
 * Swizzled implementation for waitForQuiescenceIncludingAnimationsIdle:.
 *
 * This function replaces the original quiescence waiting method to add:
 * - Conditional bypass when quiescence is disabled
 * - Custom timeout configuration from FBConfiguration
 * - Logging of quiescence wait operations
 *
 * @param self The XCUIApplicationProcess instance.
 * @param _cmd The selector being called.
 * @param includingAnimations YES to also wait for animations to complete.
 */
static void swizzledWaitForQuiescenceIncludingAnimationsIdle(id self, SEL _cmd, BOOL includingAnimations)
{
  NSString *bundleId = [self bundleID];
  if (![[self fb_shouldWaitForQuiescence] boolValue] || FBConfiguration.waitForIdleTimeout < DBL_EPSILON) {
    [FBLogger logFmt:@"Quiescence checks are disabled for %@ application. Making it to believe it is idling",
     bundleId];
    return;
  }

  NSTimeInterval desiredTimeout = FBConfiguration.waitForIdleTimeout;
  NSTimeInterval previousTimeout = _XCTApplicationStateTimeout();
  _XCTSetApplicationStateTimeout(desiredTimeout);
  [FBLogger logFmt:@"Waiting up to %@s until %@ is in idle state (%@ animations)",
   @(desiredTimeout), bundleId, includingAnimations ? @"including" : @"excluding"];
  @try {
    original_waitForQuiescenceIncludingAnimationsIdle(self, _cmd, includingAnimations);
  } @finally {
    _XCTSetApplicationStateTimeout(previousTimeout);
  }
}

/**
 * Swizzled implementation for waitForQuiescenceIncludingAnimationsIdle:isPreEvent:.
 *
 * This function is used on older iOS versions that have the two-parameter
 * quiescence method. Behavior is identical to the single-parameter version.
 *
 * @param self The XCUIApplicationProcess instance.
 * @param _cmd The selector being called.
 * @param includingAnimations YES to also wait for animations to complete.
 * @param isPreEvent YES if this is a pre-event quiescence check.
 */
static void swizzledWaitForQuiescenceIncludingAnimationsIdlePreEvent(id self, SEL _cmd, BOOL includingAnimations, BOOL isPreEvent)
{
  NSString *bundleId = [self bundleID];
  if (![[self fb_shouldWaitForQuiescence] boolValue] || FBConfiguration.waitForIdleTimeout < DBL_EPSILON) {
    [FBLogger logFmt:@"Quiescence checks are disabled for %@ application. Making it to believe it is idling",
     bundleId];
    return;
  }

  NSTimeInterval desiredTimeout = FBConfiguration.waitForIdleTimeout;
  NSTimeInterval previousTimeout = _XCTApplicationStateTimeout();
  _XCTSetApplicationStateTimeout(desiredTimeout);
  [FBLogger logFmt:@"Waiting up to %@s until %@ is in idle state (%@ animations)",
   @(desiredTimeout), bundleId, includingAnimations ? @"including" : @"excluding"];
  @try {
    original_waitForQuiescenceIncludingAnimationsIdlePreEvent(self, _cmd, includingAnimations, isPreEvent);
  } @finally {
    _XCTSetApplicationStateTimeout(previousTimeout);
  }
}

#pragma mark - Category Implementation

@implementation XCUIApplicationProcess (FBQuiescence)

#pragma mark - Method Swizzling Setup

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"
#pragma clang diagnostic ignored "-Wcast-function-type-strict"

/**
 * Performs method swizzling at class load time.
 *
 * This method is called automatically when the class is loaded into memory.
 * It detects which quiescence method is available and swizzles it with
 * the custom implementation.
 *
 * @note Only one of the two quiescence methods will exist depending on iOS version.
 */
+ (void)load
{
  Method waitForQuiescenceIncludingAnimationsIdleMethod = class_getInstanceMethod(self.class, @selector(waitForQuiescenceIncludingAnimationsIdle:));
  Method waitForQuiescenceIncludingAnimationsIdlePreEventMethod = class_getInstanceMethod(self.class, @selector(waitForQuiescenceIncludingAnimationsIdle:isPreEvent:));
  if (nil != waitForQuiescenceIncludingAnimationsIdleMethod) {
    IMP swizzledImp = (IMP)swizzledWaitForQuiescenceIncludingAnimationsIdle;
    original_waitForQuiescenceIncludingAnimationsIdle = (void (*)(id, SEL, BOOL)) method_setImplementation(waitForQuiescenceIncludingAnimationsIdleMethod, swizzledImp);
  } else if (nil != waitForQuiescenceIncludingAnimationsIdlePreEventMethod) {
    IMP swizzledImp = (IMP)swizzledWaitForQuiescenceIncludingAnimationsIdlePreEvent;
    original_waitForQuiescenceIncludingAnimationsIdlePreEvent = (void (*)(id, SEL, BOOL, BOOL)) method_setImplementation(waitForQuiescenceIncludingAnimationsIdlePreEventMethod, swizzledImp);
  } else {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess waitForQuiescenceIncludingAnimationsIdle:]"];
  }
}

#pragma clang diagnostic pop

#pragma mark - Associated Object Storage

/**
 * Storage key for the fb_shouldWaitForQuiescence associated object.
 * Uses a static char address as a unique key for objc_getAssociatedObject/objc_setAssociatedObject.
 */
static char XCUIAPPLICATIONPROCESS_SHOULD_WAIT_FOR_QUIESCENCE;

@dynamic fb_shouldWaitForQuiescence;

#pragma mark - Property Accessors

/**
 * Gets the quiescence waiting preference for this process.
 *
 * @return NSNumber containing YES (default) or NO based on stored preference.
 */
- (NSNumber *)fb_shouldWaitForQuiescence
{
  id result = objc_getAssociatedObject(self, &XCUIAPPLICATIONPROCESS_SHOULD_WAIT_FOR_QUIESCENCE);
  if (nil == result) {
    return @(YES);
  }
  return (NSNumber *)result;
}

/**
 * Sets the quiescence waiting preference for this process.
 *
 * @param value NSNumber containing YES to enable quiescence checks, NO to disable.
 */
- (void)setFb_shouldWaitForQuiescence:(NSNumber *)value
{
  objc_setAssociatedObject(self, &XCUIAPPLICATIONPROCESS_SHOULD_WAIT_FOR_QUIESCENCE, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Public Methods

/**
 * Waits for the application process to become idle.
 *
 * This method provides a version-agnostic wrapper around the internal quiescence
 * methods. It automatically detects which method is available on the current
 * iOS version and calls it appropriately.
 *
 * @param waitForAnimations YES to also wait for animations to complete,
 *                          NO to only wait for general quiescence.
 *
 * @throws NSException with name "NoApiFound" if no compatible quiescence method exists.
 */
- (void)fb_waitForQuiescenceIncludingAnimationsIdle:(bool)waitForAnimations
{
  if ([self respondsToSelector:@selector(waitForQuiescenceIncludingAnimationsIdle:)]) {
    [self waitForQuiescenceIncludingAnimationsIdle:waitForAnimations];
  } else if ([self respondsToSelector:@selector(waitForQuiescenceIncludingAnimationsIdle:isPreEvent:)]) {
    [self waitForQuiescenceIncludingAnimationsIdle:waitForAnimations isPreEvent:NO];
  } else {
      @throw [NSException exceptionWithName: @"NoApiFound" reason:@"The current driver build is not compatible to your device OS version" userInfo:@{}];
  }
}


@end
