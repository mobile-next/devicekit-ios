/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * @file FBConfiguration.h
 * @brief Global configuration settings for idle timeout and animation handling.
 *
 * This class provides centralized configuration for timeout values used during
 * application quiescence checks and animation cool-off periods.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @class FBConfiguration
 * @brief Global configuration singleton for timeout settings.
 *
 * Provides class methods to get and set timeout values that control how long
 * the test driver waits for application idle state and animations to complete.
 *
 * ## Timeout Values
 *
 * - **waitForIdleTimeout**: Controls quiescence waiting before UI operations.
 *   Set to 0 to disable quiescence checks entirely.
 *
 * - **animationCoolOffTimeout**: Controls waiting after events like rotation
 *   changes or gesture synthesis for animations to settle.
 *
 * @note These timeouts are used by XCUIApplicationProcess+FBQuiescence swizzling.
 */
@interface FBConfiguration : NSObject

#pragma mark - Idle Timeout

/**
 * Sets the timeout for waiting until the application becomes idle.
 *
 * If the timeout expires, the driver proceeds with the operation even if
 * the application is still animating or processing events.
 *
 * @param timeout The timeout value in seconds. Set to 0 to disable idle checks.
 *
 * @note Default value is 10 seconds.
 *
 * @code
 * // Set a 5 second idle timeout
 * [FBConfiguration setWaitForIdleTimeout:5.0];
 *
 * // Disable idle waiting entirely
 * [FBConfiguration setWaitForIdleTimeout:0];
 * @endcode
 */
+ (void)setWaitForIdleTimeout:(NSTimeInterval)timeout;

/**
 * Gets the current idle timeout value.
 *
 * @return The timeout value in seconds.
 */
+ (NSTimeInterval)waitForIdleTimeout;

#pragma mark - Animation Cool-Off Timeout

/**
 * Sets the timeout for waiting after actions that may trigger animations.
 *
 * This timeout applies after events like device rotation, gesture synthesis,
 * or other operations that commonly trigger UI animations.
 *
 * @param timeout The timeout value in seconds. Set to 0 to disable.
 *
 * @note Default value is 2 seconds.
 *
 * @code
 * // Set a 3 second animation cool-off
 * [FBConfiguration setAnimationCoolOffTimeout:3.0];
 * @endcode
 */
+ (void)setAnimationCoolOffTimeout:(NSTimeInterval)timeout;

/**
 * Gets the current animation cool-off timeout value.
 *
 * @return The timeout value in seconds.
 */
+ (NSTimeInterval)animationCoolOffTimeout;

@end

NS_ASSUME_NONNULL_END
