/**
 * @file AXClientProxy.m
 * @brief Implementation of AXClientProxy singleton.
 */

#import "AXClientProxy.h"
#import "XCAXClient_iOS.h"

#import <dlfcn.h>
#import "XCAccessibilityElement.h"
#import "XCUIDevice.h"

/// Cached reference to the accessibility client interface (XCAXClient_iOS).
static id AXClient = nil;

@implementation AXClientProxy

#pragma mark - Singleton

+ (instancetype)sharedClient {
    static AXClientProxy *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      instance = [[self alloc] init];
      // Access private accessibilityInterface property from XCUIDevice
      AXClient = [XCUIDevice.sharedDevice accessibilityInterface];
    });
    return instance;
}

#pragma mark - Public Methods

- (NSArray<id<XCAccessibilityElement>> *)activeApplications {
    return [AXClient activeApplications];
}

- (NSDictionary *)defaultParameters {
    return [AXClient defaultParameters];
}

#pragma mark - View Controller

/**
 * Accessibility attribute carrying the view controller class name of an
 * element. The snapshot reports extra attributes by numeric code rather than by
 * name; 5042 is the code XCTest knows as
 * XC_kAXXCAttributeViewControllerClassName.
 */
static const NSInteger AXViewControllerClassNameAttribute = 5042;

/** The name the request is made with; the reply is keyed by the code above. */
static NSString *const AXViewControllerClassNameAttributeName =
    @"XC_kAXXCAttributeViewControllerClassName";

/** How far down the element tree to look for a view controller. */
static const NSInteger AXViewControllerSearchDepth = 60;

/** Signature of swift_demangle, exported by libswiftCore. */
typedef char *(*SwiftDemangleFunction)(const char *mangledName, size_t mangledNameLength,
                                       char *outputBuffer, size_t *outputBufferSize,
                                       uint32_t flags);

/**
 * Turns a mangled Swift class name into a readable one, so that
 * _TtGC7SwiftUI32NavigationStackHostingControllerVS_7AnyView_ reads as
 * SwiftUI.NavigationStackHostingController<SwiftUI.AnyView>.
 *
 * Objective-C class names carry no mangling and are returned unchanged, as is
 * anything the demangler cannot parse.
 */
static NSString *DemangledClassName(NSString *name) {
    if (![name hasPrefix:@"_Tt"] && ![name hasPrefix:@"$s"]) {
        return name;
    }

    static SwiftDemangleFunction demangle = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      demangle = (SwiftDemangleFunction)dlsym(RTLD_DEFAULT, "swift_demangle");
    });

    if (NULL == demangle) {
        return name;
    }

    const char *mangled = name.UTF8String;
    char *demangled = demangle(mangled, strlen(mangled), NULL, NULL, 0);
    if (NULL == demangled) {
        return name;
    }

    NSString *readable = @(demangled);
    free(demangled);
    return readable.length > 0 ? readable : name;
}

/**
 * Walks a snapshot subtree and returns the view controller class name found
 * deepest in it, which is the controller closest to what is on screen.
 */
static NSString *_Nullable DeepestViewControllerClassName(id snapshot, NSInteger depth,
                                                          NSInteger *foundDepth) {
    // these keys are private API and could disappear between XCTest versions;
    // valueForKey: would raise and take the test host down with it
    if (![snapshot respondsToSelector:@selector(additionalAttributes)] ||
        ![snapshot respondsToSelector:@selector(children)]) {
        NSLog(@"Snapshot of class %@ does not expose the expected keys",
              NSStringFromClass([snapshot class]));
        return nil;
    }

    NSString *result = nil;
    NSDictionary *attributes = [snapshot valueForKey:@"additionalAttributes"];
    id className = attributes[@(AXViewControllerClassNameAttribute)];
    if ([className isKindOfClass:NSString.class] && [className length] > 0) {
        result = className;
        *foundDepth = depth;
    }

    for (id child in [snapshot valueForKey:@"children"]) {
        NSInteger childDepth = -1;
        NSString *fromChild = DeepestViewControllerClassName(child, depth + 1, &childDepth);
        if (nil != fromChild && childDepth > *foundDepth) {
            result = fromChild;
            *foundDepth = childDepth;
        }
    }

    return result;
}

- (nullable NSString *)viewControllerClassNameForProcessIdentifier:(int)pid {
    // the elements stay in Objective-C: the reverse-engineered
    // XCAccessibilityElement protocol does not bridge to Swift as an array
    id element = nil;
    for (id<XCAccessibilityElement> candidate in [AXClient activeApplications]) {
        if (candidate.processIdentifier == pid) {
            element = candidate;
            break;
        }
    }

    if (nil == element) {
        return nil;
    }

    NSMutableDictionary *parameters =
        [NSMutableDictionary dictionaryWithDictionary:[AXClient defaultParameters]];
    parameters[@"maxDepth"] = @(AXViewControllerSearchDepth);

    NSError *error = nil;
    id result = [AXClient requestSnapshotForElement:element
                                         attributes:@[ AXViewControllerClassNameAttributeName ]
                                         parameters:parameters
                                              error:&error];
    // the return value decides success; error is only diagnostic
    if (nil == result) {
        NSLog(@"View controller snapshot failed: %@", error);
        return nil;
    }

    id snapshot = [result valueForKey:@"rootElementSnapshot"];
    if (nil == snapshot) {
        return nil;
    }

    NSInteger foundDepth = -1;
    NSString *className = DeepestViewControllerClassName(snapshot, 0, &foundDepth);
    return nil == className ? nil : DemangledClassName(className);
}

@end
