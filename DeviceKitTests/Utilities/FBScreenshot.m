/**
 * @file FBScreenshot.m
 * @brief Implementation of fast screenshot capture using modern XCTest API.
 */

#import "FBScreenshot.h"
#import "FBLogger.h"
#import "XCTestDaemonsProxy.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCUIScreen.h"
#import <objc/message.h>

@import UniformTypeIdentifiers;

@implementation FBScreenshot

+ (nullable NSData *)captureJPEGWithQuality:(double)quality
                                    timeout:(NSTimeInterval)timeout
                                      error:(NSError *_Nullable *_Nullable)error
{
    long long screenID = [self mainScreenDisplayID];
    return [self captureJPEGWithScreenID:screenID
                                 quality:quality
                                 timeout:timeout
                                   error:error];
}

+ (nullable UIImage *)captureUIImageWithQuality:(double)quality
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError *_Nullable *_Nullable)error
{
    long long screenID = [self mainScreenDisplayID];
    return [self captureUIImageWithScreenID:screenID
                                    quality:quality
                                    timeout:timeout
                                      error:error];
}

+ (nullable UIImage *)capturePNGImageWithTimeout:(NSTimeInterval)timeout
                                           error:(NSError *_Nullable *_Nullable)error
{
    long long screenID = [self mainScreenDisplayID];
    return [self captureUIImageWithScreenID:screenID
                                        uti:UTTypePNG
                         compressionQuality:1.0
                                    timeout:timeout
                                      error:error];
}

+ (nullable UIImage *)captureUIImageWithScreenID:(long long)screenID
                                         quality:(double)quality
                                         timeout:(NSTimeInterval)timeout
                                           error:(NSError *_Nullable *_Nullable)error
{
    return [self captureUIImageWithScreenID:screenID
                                        uti:UTTypeJPEG
                         compressionQuality:quality
                                    timeout:timeout
                                      error:error];
}

+ (nullable UIImage *)captureUIImageWithScreenID:(long long)screenID
                                             uti:(UTType *)uti
                              compressionQuality:(double)compressionQuality
                                         timeout:(NSTimeInterval)timeout
                                           error:(NSError *_Nullable *_Nullable)error
{
    // Start timing
    uint64_t startTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);

    // Create screenshot request using modern API
    id screenshotRequest = [self screenshotRequestWithScreenID:screenID
                                                          rect:CGRectNull
                                                           uti:uti
                                            compressionQuality:compressionQuality
                                                         error:error];
    if (nil == screenshotRequest) {
        return nil;
    }

    id<XCTestManager_ManagerInterface> proxy = [XCTestDaemonsProxy testRunnerProxy];

    __block UIImage *uiImage = nil;
    __block NSError *innerError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // Use modern API: _XCT_requestScreenshot:withReply:
    [proxy _XCT_requestScreenshot:screenshotRequest
                        withReply:^(id image, NSError *err) {
        if (err != nil) {
            innerError = err;
        } else if (image != nil) {
            if ([image respondsToSelector:@selector(platformImage)]) {
                uiImage = [image performSelector:@selector(platformImage)];
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];

    // Wait with timeout
    int64_t timeoutNs = (int64_t)(timeout * NSEC_PER_SEC);
    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, timeoutNs)) != 0) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"FBScreenshot"
                                         code:1
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Screenshot capture timed out"
                                     }];
        }
        [FBLogger logFmt:@"Screenshot capture timed out after %.2fs", timeout];
        return nil;
    }

    if (innerError != nil) {
        if (error != nil) {
            *error = innerError;
        }
        [FBLogger logFmt:@"Screenshot capture failed: %@", innerError.localizedDescription];
        return nil;
    }

    // Log timing
    uint64_t elapsedNs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - startTime;
    double elapsedMs = (double)elapsedNs / 1000000.0;
    CGSize size = uiImage.size;

    return uiImage;
}

+ (nullable NSData *)captureJPEGWithScreenID:(long long)screenID
                                     quality:(double)quality
                                     timeout:(NSTimeInterval)timeout
                                       error:(NSError *_Nullable *_Nullable)error
{
    // Start timing
    uint64_t startTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);

    // Create screenshot request using modern API
    id screenshotRequest = [self screenshotRequestWithScreenID:screenID
                                                          rect:CGRectNull
                                                           uti:UTTypeJPEG
                                            compressionQuality:quality
                                                         error:error];
    if (nil == screenshotRequest) {
        return nil;
    }

    id<XCTestManager_ManagerInterface> proxy = [XCTestDaemonsProxy testRunnerProxy];

    __block NSData *screenshotData = nil;
    __block NSError *innerError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // Use modern API: _XCT_requestScreenshot:withReply:
    [proxy _XCT_requestScreenshot:screenshotRequest
                        withReply:^(id image, NSError *err) {
        if (err != nil) {
            innerError = err;
        } else if (image != nil) {
            // XCTImage has a 'data' property that returns NSData
            if ([image respondsToSelector:@selector(data)]) {
                screenshotData = [image performSelector:@selector(data)];
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];

    // Wait with timeout
    int64_t timeoutNs = (int64_t)(timeout * NSEC_PER_SEC);
    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, timeoutNs)) != 0) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"FBScreenshot"
                                         code:1
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Screenshot capture timed out"
                                     }];
        }
        [FBLogger logFmt:@"Screenshot capture timed out after %.2fs", timeout];
        return nil;
    }

    if (innerError != nil) {
        if (error != nil) {
            *error = innerError;
        }
        [FBLogger logFmt:@"Screenshot capture failed: %@", innerError.localizedDescription];
        return nil;
    }

    // Log timing
    uint64_t elapsedNs = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - startTime;
    double elapsedMs = (double)elapsedNs / 1000000.0;
    NSUInteger dataSize = screenshotData.length;

    return screenshotData;
}

+ (long long)mainScreenDisplayID
{
    return XCUIScreen.mainScreen.displayID;
}

#pragma mark - Private Methods

/**
 * Creates an XCTImageEncoding object for the specified format and quality.
 */
+ (nullable id)imageEncodingWithUniformTypeIdentifier:(UTType *)uti
                                   compressionQuality:(CGFloat)compressionQuality
                                                error:(NSError **)error
{
    Class imageEncodingClass = NSClassFromString(@"XCTImageEncoding");
    if (nil == imageEncodingClass) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"FBScreenshot"
                                         code:2
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Cannot find XCTImageEncoding class"
                                     }];
        }
        return nil;
    }

    id imageEncodingAllocated = [imageEncodingClass alloc];
    SEL imageEncodingConstructorSelector = NSSelectorFromString(@"initWithUniformTypeIdentifier:compressionQuality:");
    if (![imageEncodingAllocated respondsToSelector:imageEncodingConstructorSelector]) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"FBScreenshot"
                                         code:3
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"XCTImageEncoding constructor not found"
                                     }];
        }
        return nil;
    }

    NSMethodSignature *signature = [imageEncodingAllocated methodSignatureForSelector:imageEncodingConstructorSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:imageEncodingConstructorSelector];
    NSString *utiIdentifier = uti.identifier;
    [invocation setArgument:&utiIdentifier atIndex:2];
    [invocation setArgument:&compressionQuality atIndex:3];
    [invocation invokeWithTarget:imageEncodingAllocated];

    id __unsafe_unretained imageEncoding;
    [invocation getReturnValue:&imageEncoding];
    return imageEncoding;
}

/**
 * Creates an XCTScreenshotRequest object for the specified parameters.
 */
+ (nullable id)screenshotRequestWithScreenID:(long long)screenID
                                        rect:(CGRect)rect
                                         uti:(UTType *)uti
                          compressionQuality:(CGFloat)compressionQuality
                                       error:(NSError **)error
{
    id imageEncoding = [self imageEncodingWithUniformTypeIdentifier:uti
                                                 compressionQuality:compressionQuality
                                                              error:error];
    if (nil == imageEncoding) {
        return nil;
    }

    Class screenshotRequestClass = NSClassFromString(@"XCTScreenshotRequest");
    if (nil == screenshotRequestClass) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"FBScreenshot"
                                         code:4
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Cannot find XCTScreenshotRequest class"
                                     }];
        }
        return nil;
    }

    id screenshotRequestAllocated = [screenshotRequestClass alloc];
    SEL constructorSelector = NSSelectorFromString(@"initWithScreenID:rect:encoding:");
    if (![screenshotRequestAllocated respondsToSelector:constructorSelector]) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"FBScreenshot"
                                         code:5
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"XCTScreenshotRequest constructor not found"
                                     }];
        }
        return nil;
    }

    NSMethodSignature *signature = [screenshotRequestAllocated methodSignatureForSelector:constructorSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:constructorSelector];
    [invocation setArgument:&screenID atIndex:2];
    [invocation setArgument:&rect atIndex:3];
    [invocation setArgument:&imageEncoding atIndex:4];
    [invocation invokeWithTarget:screenshotRequestAllocated];

    id __unsafe_unretained screenshotRequest;
    [invocation getReturnValue:&screenshotRequest];
    return screenshotRequest;
}

@end
