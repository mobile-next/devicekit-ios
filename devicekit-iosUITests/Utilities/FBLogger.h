/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * @file FBLogger.h
 * @brief Global logging utility with support for standard and verbose logging.
 *
 * Provides a centralized logging interface for the test driver, with methods
 * for both standard and verbose (debug-level) log output.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @class FBLogger
 * @brief Global logging utility for test driver output.
 *
 * A simple logging interface that wraps NSLog for consistent log output.
 * Supports both standard logging (always output) and verbose logging
 * (for debug-level information).
 *
 * @code
 * // Standard logging
 * [FBLogger log:@"Starting test execution"];
 * [FBLogger logFmt:@"Processing element: %@", elementId];
 *
 * // Verbose/debug logging
 * [FBLogger verboseLog:@"Detailed debug information"];
 * [FBLogger verboseLogFmt:@"Element frame: %@", NSStringFromCGRect(frame)];
 * @endcode
 */
@interface FBLogger : NSObject

#pragma mark - Standard Logging

/**
 * Logs a message to stdout via NSLog.
 *
 * @param message The message string to log.
 *
 * @code
 * [FBLogger log:@"Application launched successfully"];
 * @endcode
 */
+ (void)log:(NSString *)message;

/**
 * Logs a formatted message to stdout via NSLog.
 *
 * @param format The format string (supports NSLog format specifiers).
 * @param ... Variable arguments for format substitution.
 *
 * @code
 * [FBLogger logFmt:@"Found %lu elements matching %@", (unsigned long)count, query];
 * @endcode
 */
+ (void)logFmt:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

#pragma mark - Verbose Logging

/**
 * Logs a message when verbose mode is enabled.
 *
 * Use for debug-level information that is helpful during development
 * but may be too noisy for normal operation.
 *
 * @param message The message string to log.
 *
 * @note Currently verbose logging always outputs. Future versions may
 *       support conditional verbose output based on configuration.
 */
+ (void)verboseLog:(NSString *)message;

/**
 * Logs a formatted message when verbose mode is enabled.
 *
 * @param format The format string (supports NSLog format specifiers).
 * @param ... Variable arguments for format substitution.
 *
 * @note Currently verbose logging always outputs.
 */
+ (void)verboseLogFmt:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

@end

NS_ASSUME_NONNULL_END
