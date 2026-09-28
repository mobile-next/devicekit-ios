#import <UIKit/UIKit.h>
#import <objc/message.h>

// XCUIInitializeForUITesting waits up to 30s for the test runner to enter the background.
// xcodebuild's testmanagerd session does that, but on iOS 27 simulators nothing backgrounds a
// runner started with a plain `simctl launch`, so initialization fails with
// "Failed to background test runner within 30.0s". Suspend ourselves in that case.
static const NSTimeInterval FBRunnerSuspendDelay = 2.0;

__attribute__((constructor)) static void FBScheduleRunnerSuspend(void)
{
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(FBRunnerSuspendDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    UIApplication *application = UIApplication.sharedApplication;
    if (application.applicationState == UIApplicationStateBackground) {
      return;
    }

    SEL suspend = NSSelectorFromString(@"suspend");
    if (![application respondsToSelector:suspend]) {
      NSLog(@"[DeviceKit] UIApplication does not respond to -suspend, cannot background the test runner");
      return;
    }

    NSLog(@"[DeviceKit] Suspending test runner so UI testing can initialize");
    ((void (*)(id, SEL))objc_msgSend)(application, suspend);
  });
}
