/**
 * @file FBScreenshot.h
 * @brief Fast screenshot capture using XCTest daemon proxy.
 *
 * Provides fast screenshot capture by directly communicating with the
 * XCTest daemon, bypassing the slower XCUIScreen.screenshot() API.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKey.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @class FBScreenshot
 * @brief Utility class for fast screenshot capture.
 *
 * Uses the XCTest daemon proxy to capture screenshots with JPEG compression
 * at the source level for optimal performance in streaming scenarios.
 */
@interface FBScreenshot : NSObject

/**
 * Captures a JPEG screenshot from the main screen.
 *
 * @param quality JPEG compression quality (0.0 - 1.0). Lower values = smaller
 * size.
 * @param timeout Maximum time to wait for screenshot capture in seconds.
 * @param error On return, contains an error if the capture failed.
 * @return JPEG image data, or nil if capture failed.
 */
+ (nullable NSData *)captureJPEGWithQuality:(double)quality
                                    timeout:(NSTimeInterval)timeout
                                      error:(NSError *_Nullable *_Nullable)error;

/**
 * Captures a JPEG screenshot from a specific screen.
 *
 * @param screenID The display ID of the screen to capture.
 * @param quality JPEG compression quality (0.0 - 1.0).
 * @param timeout Maximum time to wait for screenshot capture in seconds.
 * @param error On return, contains an error if the capture failed.
 * @return JPEG image data, or nil if capture failed.
 */
+ (nullable NSData *)captureJPEGWithScreenID:(long long)screenID
                                     quality:(double)quality
                                     timeout:(NSTimeInterval)timeout
                                       error:(NSError *_Nullable *_Nullable)error;

/**
 * Captures a screenshot from a specific screen and returns it as a UIImage.
 *
 * @param quality JPEG compression quality (0.0 – 1.0). Used only when the
 *                underlying screenshot request encodes JPEG data.
 * @param timeout Maximum time to wait for screenshot capture, in seconds.
 * @param error   On return, contains an error if the capture failed.
 *
 * @return A UIImage representing the captured screenshot, or nil
 *         if the capture failed or timed out.
 */
+ (nullable UIImage *)captureUIImageWithQuality:(double)quality
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError *_Nullable *_Nullable)error;

/**
 * Captures a lossless PNG screenshot from the main screen.
 *
 * This method is preferred for H.264 encoding as it provides better source
 * quality compared to JPEG (no compression artifacts).
 *
 * @param timeout Maximum time to wait for screenshot capture, in seconds.
 * @param error   On return, contains an error if the capture failed.
 *
 * @return A UIImage representing the captured screenshot in PNG format, or nil
 *         if the capture failed or timed out.
 */
+ (nullable UIImage *)capturePNGImageWithTimeout:(NSTimeInterval)timeout
                                           error:(NSError *_Nullable *_Nullable)error;
/**
 * Returns the display ID of the main screen.
 *
 * @return The main screen's display ID.
 */
+ (long long)mainScreenDisplayID;

@end

NS_ASSUME_NONNULL_END
