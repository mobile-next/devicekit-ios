/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * @file FBConfiguration.m
 * @brief Implementation of FBConfiguration global settings.
 *
 * Stores timeout values in static variables for global access throughout
 * the test driver.
 */

#import "FBConfiguration.h"

#include "TargetConditionals.h"
#import "XCTestConfiguration.h"

#pragma mark - Static Storage

/** Timeout for waiting until application becomes idle (quiescence). */
static NSTimeInterval FBWaitForIdleTimeout;

/** Timeout for animation cool-off after events. */
static NSTimeInterval FBAnimationCoolOffTimeout;

#pragma mark - Implementation

@implementation FBConfiguration

#pragma mark - Idle Timeout

+ (NSTimeInterval)waitForIdleTimeout
{
  return FBWaitForIdleTimeout;
}

+ (void)setWaitForIdleTimeout:(NSTimeInterval)timeout
{
  FBWaitForIdleTimeout = timeout;
}

#pragma mark - Animation Cool-Off Timeout

+ (NSTimeInterval)animationCoolOffTimeout
{
  return FBAnimationCoolOffTimeout;
}

+ (void)setAnimationCoolOffTimeout:(NSTimeInterval)timeout
{
  FBAnimationCoolOffTimeout = timeout;
}

@end
