/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * @file XCUIApplication+FBQuiescence.h
 * @brief Category for controlling application quiescence behavior.
 *
 * Quiescence refers to the idle state of an application where no animations
 * or background tasks are running. XCTest waits for quiescence before
 * performing UI operations to ensure stability.
 *
 * This category provides control over whether quiescence checks should be
 * performed, which can speed up tests when idle waiting is unnecessary.
 *
 * @code
 * XCUIApplication *app = [[XCUIApplication alloc] init];
 * app.fb_shouldWaitForQuiescence = NO;  // Disable quiescence waiting
 * [app launch];
 * @endcode
 */

#import "XCUIApplication.h"
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @category XCUIApplication (FBQuiescence)
 * @brief Controls quiescence waiting behavior for XCUIApplication.
 */
@interface XCUIApplication (FBQuiescence)

/**
 * Controls whether to wait for application quiescence during queries.
 *
 * When YES (default), XCTest waits for the application to become idle
 * before performing UI operations. Set to NO to skip quiescence checks
 * and speed up test execution.
 *
 * @note This property mirrors the underlying XCUIApplicationProcess property.
 */
@property(nonatomic, assign) BOOL fb_shouldWaitForQuiescence;

@end

NS_ASSUME_NONNULL_END
