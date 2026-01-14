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

#pragma mark - Factory Methods

/**
 * Creates an element from a Core Foundation AXUIElement.
 * @param arg1 The AXUIElement reference.
 * @return A new accessibility element instance.
 */
+ (id)elementWithAXUIElement:(struct __AXUIElement *)arg1;

/**
 * Creates an element for a process by its identifier.
 * @param arg1 The process identifier (PID).
 * @return A new accessibility element instance.
 */
+ (id)elementWithProcessIdentifier:(int)arg1;

/**
 * Returns the accessibility element representing the device.
 * @return The device accessibility element.
 */
+ (id)deviceElement;

/**
 * Creates a mock element for testing purposes.
 * @param arg1 Mock process identifier.
 * @param arg2 Mock payload data.
 * @return A mock accessibility element.
 */
+ (id)mockElementWithProcessIdentifier:(int)arg1 payload:(id)arg2;

/**
 * Creates a mock element with default payload.
 * @param arg1 Mock process identifier.
 * @return A mock accessibility element.
 */
+ (id)mockElementWithProcessIdentifier:(int)arg1;

#pragma mark - Initializers

/**
 * Initializes a mock element with process ID and payload.
 * @param arg1 Mock process identifier.
 * @param arg2 Mock payload data.
 * @return An initialized mock element.
 */
- (id)initWithMockProcessIdentifier:(int)arg1 payload:(id)arg2;

/**
 * Initializes an element from a Core Foundation AXUIElement.
 * @param arg1 The AXUIElement reference.
 * @return An initialized accessibility element.
 */
- (id)initWithAXUIElement:(struct __AXUIElement *)arg1;

/** Default initializer. */
- (id)init;

@end

NS_ASSUME_NONNULL_END
