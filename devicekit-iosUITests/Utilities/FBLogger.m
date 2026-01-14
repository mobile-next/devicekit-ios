/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

/**
 * @file FBLogger.m
 * @brief Implementation of FBLogger logging utility.
 *
 * Simple wrapper around NSLog/NSLogv for consistent logging output.
 * Both standard and verbose methods currently log to stdout.
 */

#import "FBLogger.h"

@implementation FBLogger

#pragma mark - Standard Logging

+ (void)log:(NSString *)message
{
  NSLog(@"%@", message);
}

+ (void)logFmt:(NSString *)format, ...
{
  va_list args;
  va_start(args, format);
  NSLogv(format, args);
  va_end(args);
}

#pragma mark - Verbose Logging

+ (void)verboseLog:(NSString *)message
{
  [self log:message];
}

+ (void)verboseLogFmt:(NSString *)format, ...
{
  va_list args;
  va_start(args, format);
  NSLogv(format, args);
  va_end(args);
}

@end
