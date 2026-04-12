import Foundation
import XCTest

struct SourceTreeRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(frame: AXFrame) {
        self.x = frame["X"] ?? 0
        self.y = frame["Y"] ?? 0
        self.width = frame["Width"] ?? 0
        self.height = frame["Height"] ?? 0
    }
}

struct SourceTreeElement: Codable {
    let type: String
    let label: String?
    let name: String?
    let value: String?
    let rawIdentifier: String?
    let rect: SourceTreeRect
    let children: [SourceTreeElement]?

    init(axElement: AXElement) {
        self.type = Self.elementTypeName(axElement.elementType)
        self.label = axElement.label.isEmpty ? nil : axElement.label
        let identifier = axElement.identifier.isEmpty ? nil : axElement.identifier
        self.name = identifier ?? (axElement.label.isEmpty ? nil : axElement.label)
        self.value = axElement.value
        self.rawIdentifier = identifier
        self.rect = SourceTreeRect(frame: axElement.frame)
        self.children = axElement.children?.isEmpty == true ? nil : axElement.children?.map { SourceTreeElement(axElement: $0) }
    }

    private static let elementTypeNames: [Int: String] = [
        0: "Any", 1: "Other", 2: "Application", 3: "Group", 4: "Window",
        5: "Sheet", 6: "Drawer", 7: "Alert", 8: "Dialog", 9: "Button",
        10: "RadioButton", 11: "RadioGroup", 12: "CheckBox",
        13: "DisclosureTriangle", 14: "PopUpButton", 15: "ComboBox",
        16: "MenuButton", 17: "ToolbarButton", 18: "Popover",
        19: "Keyboard", 20: "Key", 21: "NavigationBar", 22: "TabBar",
        23: "TabGroup", 24: "Toolbar", 25: "StatusBar", 26: "Table",
        27: "TableRow", 28: "TableColumn", 29: "Outline", 30: "OutlineRow",
        31: "Browser", 32: "CollectionView", 33: "Slider",
        34: "PageIndicator", 35: "ProgressIndicator",
        36: "ActivityIndicator", 37: "SegmentedControl", 38: "Picker",
        39: "PickerWheel", 40: "Switch", 41: "Toggle", 42: "Link",
        43: "Image", 44: "Icon", 45: "SearchField", 46: "ScrollView",
        47: "ScrollBar", 48: "StaticText", 49: "TextField",
        50: "SecureTextField", 51: "DatePicker", 52: "TextView",
        53: "Menu", 54: "MenuItem", 55: "MenuBar", 56: "MenuBarItem",
        57: "Map", 58: "WebView", 59: "IncrementArrow",
        60: "DecrementArrow", 61: "Timeline", 62: "RatingIndicator",
        63: "ValueIndicator", 64: "SplitGroup", 65: "Splitter",
        66: "RelevanceIndicator", 67: "ColorWell", 68: "HelpTag",
        69: "Matte", 70: "DockItem", 71: "Ruler", 72: "RulerMarker",
        73: "Grid", 74: "LevelIndicator", 75: "Cell", 76: "LayoutArea",
        77: "LayoutItem", 78: "Handle", 79: "Stepper", 80: "Tab",
        81: "TouchBar", 82: "StatusItem",
    ]

    private static func elementTypeName(_ rawValue: Int) -> String {
        "XCUIElementType" + (elementTypeNames[rawValue] ?? "Unknown")
    }
}

struct WindowOffset: Codable {
    let offsetX: Double
    let offsetY: Double
}

typealias AXFrame = [String: Double]

extension AXFrame {
    static var zero: Self {
        ["X": 0, "Y": 0, "Width": 0, "Height": 0]
    }
}

struct AXElement: Codable {
    let identifier: String
    let frame: AXFrame
    let value: String?
    let title: String?
    let label: String
    let elementType: Int
    let enabled: Bool
    let horizontalSizeClass: Int
    let verticalSizeClass: Int
    let placeholderValue: String?
    let selected: Bool
    let hasFocus: Bool
    var children: [AXElement]?
    let windowContextID: Double
    let displayID: Int

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

    init(
        identifier: String,
        frame: AXFrame,
        value: String?,
        title: String?,
        label: String,
        elementType: Int,
        enabled: Bool,
        horizontalSizeClass: Int,
        verticalSizeClass: Int,
        placeholderValue: String?,
        selected: Bool,
        hasFocus: Bool,
        displayID: Int,
        windowContextID: Double,
        children: [AXElement]?
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
        let childrenDictionaries =
            valueFor("children") as? [[XCUIElement.AttributeName: Any]]
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
        try container.encode(
            self.horizontalSizeClass,
            forKey: .horizontalSizeClass
        )
        try container.encode(self.verticalSizeClass, forKey: .verticalSizeClass)
        try container.encodeIfPresent(
            self.placeholderValue,
            forKey: .placeholderValue
        )
        try container.encode(self.selected, forKey: .selected)
        try container.encode(self.hasFocus, forKey: .hasFocus)
        try container.encodeIfPresent(self.children, forKey: .children)
        try container.encode(self.windowContextID, forKey: .windowContextID)
        try container.encode(self.displayID, forKey: .displayID)
    }

    func depth() -> Int {
        guard let children = children
        else { return 1 }

        let max =
            children
            .map { child in child.depth() + 1 }
            .max()

        return max ?? 1
    }
}
