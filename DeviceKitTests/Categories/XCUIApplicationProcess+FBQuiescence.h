/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * @file XCUIApplicationProcess+FBQuiescence.h
 * @brief Category for controlling process-level quiescence behavior.
 *
 * This category extends XCUIApplicationProcess to provide fine-grained
 * control over quiescence (idle state) checking. It swizzles the internal
 * quiescence methods to add custom timeout handling via FBConfiguration.
 *
 * Quiescence checking ensures the application is idle before performing
 * UI operations, but can cause slowdowns. This category allows:
 * - Disabling quiescence checks entirely
 * - Configuring custom timeout values
 * - Controlling whether to wait for animations
 */

#import <XCTest/XCTest.h>

#import "XCUIApplicationProcess.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @category XCUIApplicationProcess (FBQuiescence)
 * @brief Process-level quiescence control with method swizzling.
 *
 * This category swizzles waitForQuiescenceIncludingAnimationsIdle: to add
 * custom timeout handling based on FBConfiguration settings.
 */
@interface XCUIApplicationProcess (FBQuiescence)

/**
 * Controls whether this process should perform quiescence checks.
 *
 * When set to NO, quiescence checks are skipped entirely, making
 * the process believe it is always idle.
 *
 * @note Default value is YES. Uses associated objects for storage.
 */
@property(nonatomic) NSNumber *fb_shouldWaitForQuiescence;

@end

NS_ASSUME_NONNULL_END
