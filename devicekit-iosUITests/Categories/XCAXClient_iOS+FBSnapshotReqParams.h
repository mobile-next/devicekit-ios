/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * @file XCAXClient_iOS+FBSnapshotReqParams.h
 * @brief Category for customizing accessibility snapshot parameters.
 *
 * This category swizzles XCAXClient_iOS.defaultParameters to allow
 * custom parameters for accessibility snapshots, such as maxDepth
 * and snapshotKeyHonorModalViews.
 */

#import <XCTest/XCTest.h>

#import "XCAXClient_iOS.h"

NS_ASSUME_NONNULL_BEGIN

/** Key for the maximum snapshot depth parameter. */
extern NSString *const FBSnapshotMaxDepthKey;

/**
 * Sets a custom parameter for element snapshots.
 *
 * Custom parameters are merged with default parameters when
 * XCAXClient_iOS.defaultParameters is called.
 *
 * @param name  The parameter name (e.g., "maxDepth", "snapshotKeyHonorModalViews").
 * @param value The parameter value.
 *
 * @code
 * // Increase max snapshot depth
 * FBSetCustomParameterForElementSnapshot(@"maxDepth", @60);
 *
 * // Disable modal view honoring to see elements behind modals
 * FBSetCustomParameterForElementSnapshot(@"snapshotKeyHonorModalViews", @0);
 * @endcode
 */
void FBSetCustomParameterForElementSnapshot(NSString *name, id value);

/**
 * Gets a previously set custom snapshot parameter.
 *
 * @param name The parameter name to retrieve.
 * @return The parameter value, or nil if not set.
 */
id __nullable FBGetCustomParameterForElementSnapshot(NSString *name);

/**
 * @category XCAXClient_iOS (FBSnapshotReqParams)
 * @brief Category that swizzles defaultParameters for custom configuration.
 *
 * This category is automatically loaded and swizzles XCAXClient_iOS
 * when the `snapshotKeyHonorModalViews` environment variable is set to "false".
 * This makes elements behind modal dialogs visible in snapshots.
 */
@interface XCAXClient_iOS (FBSnapshotReqParams)

@end

NS_ASSUME_NONNULL_END
