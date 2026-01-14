import Foundation
import XCTest

// MARK: - Response Models

/// Response wrapper for the `/dumpUI` endpoint.
///
/// Contains the root accessibility element and the maximum depth of the tree.
///
/// ## JSON Format
/// ```json
/// {
///   "axElement": { ... },
///   "depth": 15
/// }
/// ```
struct ViewHierarchy: Codable {

    /// Root element of the accessibility tree.
    let axElement: AXElement

    /// Maximum depth of the hierarchy tree.
    let depth: Int
}

/// Represents frame offset adjustments for non-standard window sizes.
struct WindowOffset: Codable {

    /// Horizontal offset in points.
    let offsetX: Double

    /// Vertical offset in points.
    let offsetY: Double
}

// MARK: - Frame Type

/// Dictionary representing an element's frame with X, Y, Width, and Height.
///
/// ## JSON Format
/// ```json
/// {"X": 0, "Y": 0, "Width": 390, "Height": 844}
/// ```
typealias AXFrame = [String: Double]

extension AXFrame {
    /// Returns a zero-sized frame at origin.
    static var zero: Self {
        ["X": 0, "Y": 0, "Width": 0, "Height": 0]
    }
}

// MARK: - Accessibility Element

/// Represents a UI accessibility element in the view hierarchy.
///
/// This model mirrors the XCUIElement accessibility properties and forms
/// a recursive tree structure for the complete view hierarchy.
///
/// ## JSON Format
/// ```json
/// {
///   "identifier": "login_button",
///   "frame": {"X": 50, "Y": 100, "Width": 200, "Height": 44},
///   "label": "Login",
///   "elementType": 9,
///   "enabled": true,
///   "selected": false,
///   "hasFocus": false,
///   "value": null,
///   "title": "Login",
///   "placeholderValue": null,
///   "horizontalSizeClass": 2,
///   "verticalSizeClass": 2,
///   "windowContextID": 12345.0,
///   "displayID": 0,
///   "children": []
/// }
/// ```
///
/// ## Element Types
/// Common `elementType` values (from `XCUIElement.ElementType`):
/// - `0`: Any
/// - `1`: Other
/// - `2`: Application
/// - `9`: Button
/// - `10`: RadioButton
/// - `12`: RadioGroup
/// - `13`: CheckBox
/// - `46`: StaticText
/// - `47`: TextField
/// - `48`: SecureTextField
/// - `52`: Image
struct AXElement: Codable {

    /// Accessibility identifier set by the developer.
    let identifier: String

    /// Element's frame rectangle with X, Y, Width, Height.
    let frame: AXFrame

    /// Current value of the element (e.g., text field content).
    let value: String?

    /// Element's title attribute.
    let title: String?

    /// Accessibility label for VoiceOver.
    let label: String

    /// Element type as raw integer from `XCUIElement.ElementType`.
    let elementType: Int

    /// Whether the element is enabled for interaction.
    let enabled: Bool

    /// Horizontal size class (compact: 1, regular: 2).
    let horizontalSizeClass: Int

    /// Vertical size class (compact: 1, regular: 2).
    let verticalSizeClass: Int

    /// Placeholder text for input fields.
    let placeholderValue: String?

    /// Whether the element is currently selected.
    let selected: Bool

    /// Whether the element has keyboard focus.
    let hasFocus: Bool

    /// Child elements in the hierarchy.
    var children: [AXElement]?

    /// Window context identifier.
    let windowContextID: Double

    /// Display identifier for multi-display setups.
    let displayID: Int
    
    // MARK: - Initializers

    /// Creates a container element with only children.
    ///
    /// Used for grouping elements without a corresponding XCUIElement.
    /// - Parameter children: Array of child elements.
    init(children: [AXElement]) {
        self.children = children

        self.label = ""
        self.elementType = 0
        self.identifier = ""
        self.horizontalSizeClass = 0
        self.windowContextID = 0
        self.verticalSizeClass = 0
        self.selected = false
        self.displayID = 0
        self.hasFocus = false
        self.placeholderValue = nil
        self.value = nil
        self.frame = .zero
        self.enabled = false
        self.title = nil
    }

    /// Creates a fully specified accessibility element.
    ///
    /// - Parameters:
    ///   - identifier: Accessibility identifier.
    ///   - frame: Element frame rectangle.
    ///   - value: Current value.
    ///   - title: Element title.
    ///   - label: Accessibility label.
    ///   - elementType: Element type raw value.
    ///   - enabled: Whether enabled.
    ///   - horizontalSizeClass: Horizontal size class.
    ///   - verticalSizeClass: Vertical size class.
    ///   - placeholderValue: Placeholder text.
    ///   - selected: Selection state.
    ///   - hasFocus: Focus state.
    ///   - displayID: Display identifier.
    ///   - windowContextID: Window context.
    ///   - children: Child elements.
    init(
        identifier: String, frame: AXFrame, value: String?, title: String?, label: String,
        elementType: Int, enabled: Bool, horizontalSizeClass: Int,
        verticalSizeClass: Int, placeholderValue: String?, selected: Bool,
        hasFocus: Bool, displayID: Int, windowContextID: Double, children: [AXElement]?
    ) {
        self.identifier = identifier
        self.frame = frame
        self.value = value
        self.title = title
        self.label = label
        self.elementType = elementType
        self.enabled = enabled
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
        self.placeholderValue = placeholderValue
        self.selected = selected
        self.hasFocus = hasFocus
        self.displayID = displayID
        self.windowContextID = windowContextID
        self.children = children
    }

    /// Creates an element from an XCUIElement snapshot dictionary.
    ///
    /// - Parameter dict: Dictionary representation from `XCUIElementSnapshot.dictionaryRepresentation`.
    init(_ dict: [XCUIElement.AttributeName: Any]) {
        func valueFor(_ name: String) -> Any {
            dict[XCUIElement.AttributeName(rawValue: name)] as Any
        }
        
        self.label = valueFor("label") as? String ?? ""
        self.elementType = valueFor("elementType") as? Int ?? 0
        self.identifier = valueFor("identifier") as? String ?? ""
        self.horizontalSizeClass = valueFor("horizontalSizeClass") as? Int ?? 0
        self.windowContextID = valueFor("windowContextID") as? Double ?? 0
        self.verticalSizeClass = valueFor("verticalSizeClass") as? Int ?? 0
        self.selected = valueFor("selected") as? Bool ?? false
        self.displayID = valueFor("displayID") as? Int ?? 0
        self.hasFocus = valueFor("hasFocus") as? Bool ?? false
        self.placeholderValue = valueFor("placeholderValue") as? String
        self.value = valueFor("value") as? String
        self.frame = valueFor("frame") as? AXFrame ?? .zero
        self.enabled = valueFor("enabled") as? Bool ?? false
        self.title = valueFor("title") as? String
        let childrenDictionaries = valueFor("children") as? [[XCUIElement.AttributeName: Any]]
        self.children = childrenDictionaries?.map { AXElement($0) } ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.frame, forKey: .frame)
        try container.encodeIfPresent(self.value, forKey: .value)
        try container.encodeIfPresent(self.title, forKey: .title)
        try container.encode(self.label, forKey: .label)
        try container.encode(self.elementType, forKey: .elementType)
        try container.encode(self.enabled, forKey: .enabled)
        try container.encode(self.horizontalSizeClass, forKey: .horizontalSizeClass)
        try container.encode(self.verticalSizeClass, forKey: .verticalSizeClass)
        try container.encodeIfPresent(self.placeholderValue, forKey: .placeholderValue)
        try container.encode(self.selected, forKey: .selected)
        try container.encode(self.hasFocus, forKey: .hasFocus)
        try container.encodeIfPresent(self.children, forKey: .children)
        try container.encode(self.windowContextID, forKey: .windowContextID)
        try container.encode(self.displayID, forKey: .displayID)
    }
    
    // MARK: - Methods

    /// Calculates the maximum depth of the element tree.
    ///
    /// - Returns: The depth as an integer (1 for leaf nodes).
    func depth() -> Int {
        guard let children = children
        else { return 1 }

        let max = children
            .map { child in child.depth() + 1 }
            .max()

        return max ?? 1
    }

    /// Filters out elements that intersect with the keyboard bounds.
    ///
    /// Used when `excludeKeyboardElements` is `true` in the request.
    ///
    /// - Parameter keyboardFrame: The keyboard's frame rectangle.
    /// - Returns: Array of elements not intersecting with the keyboard.
    func filterAllChildrenNotInKeyboardBounds(_ keyboardFrame: CGRect) -> [AXElement] {
        var filteredChildren = [AXElement]()
        
        // Function to recursively filter children
        func filterChildrenRecursively(_ element: AXElement, _ ancestorAdded: Bool) {
            // Check if the element's frame intersects with the keyboard frame
            let childFrame = CGRect(
                x: element.frame["X"] ?? 0,
                y: element.frame["Y"] ?? 0,
                width: element.frame["Width"] ?? 0,
                height: element.frame["Height"] ?? 0
            )
            
            var currentAncestorAdded = ancestorAdded
            
            // If it does not intersect, and no ancestor has been added, append the element
            if !keyboardFrame.intersects(childFrame) && !ancestorAdded {
                filteredChildren.append(element)
                currentAncestorAdded = true // Prevent adding descendants of this element
            }
            
            // Continue recursion with children
            element.children?.forEach { child in
                filterChildrenRecursively(child, currentAncestorAdded)
            }
        }
        
        // Start the recursive filtering with no ancestor added
        filterChildrenRecursively(self, false)
        return filteredChildren
    }
}
