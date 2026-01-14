/**
 * @file XCAccessibilityElement.h
 * @brief Protocol declaration for XCTest's private accessibility element interface.
 *
 * This header declares the XCAccessibilityElement protocol which mirrors
 * XCTest's internal accessibility element representation used for
 * identifying running applications and UI elements.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @protocol XCAccessibilityElement
 * @brief Protocol representing an accessibility element in XCTest's internal API.
 *
 * This protocol defines the interface for accessibility elements used by
 * XCTest for UI automation. Elements can represent applications, UI controls,
 * or the device itself.
 *
 * @note This is a reverse-engineered protocol matching XCTest's private API.
 */
@protocol XCAccessibilityElement <NSObject>

#pragma mark - Properties

/** Custom payload data associated with the element. */
@property(readonly) id payload;

/** Process identifier (PID) of the application owning this element. */
@property(readonly) int processIdentifier;

/** Core Foundation accessibility element reference. */
@property(readonly) const struct __AXUIElement *AXUIElement;

/** Whether this element is a native (non-mock) accessibility element. */
@property(readonly, getter=isNative) BOOL native;

/** Default initializer. */
- (id)init;

@end

NS_ASSUME_NONNULL_END
