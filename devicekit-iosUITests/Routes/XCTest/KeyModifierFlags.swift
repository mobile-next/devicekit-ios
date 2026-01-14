// MARK: - Key Modifier Flags

/// Keyboard modifier flags for synthesizing key events with modifiers.
///
/// Used with `PointerEventPath.set(modifiers:)` to simulate keyboard shortcuts.
///
/// ## Usage
/// ```swift
/// var path = PointerEventPath.pathForTextInput()
/// path.set(modifiers: [.command, .shift])  // Cmd+Shift
/// path.type(text: "A", typingSpeed: 60)    // Cmd+Shift+A
/// ```
///
/// ## Available Modifiers
/// - `capsLock`: Caps Lock key
/// - `shift`: Shift key
/// - `control`: Control key
/// - `option`: Option/Alt key
/// - `command`: Command key (⌘)
/// - `function`: Function (Fn) key
struct KeyModifierFlags: OptionSet {

    /// The raw bitmask value.
    let rawValue: UInt64

    /// Caps Lock modifier.
    static let capsLock = KeyModifierFlags(rawValue: 1 << 0)

    /// Shift modifier.
    static let shift = KeyModifierFlags(rawValue: 1 << 1)

    /// Control modifier.
    static let control = KeyModifierFlags(rawValue: 1 << 2)

    /// Option/Alt modifier.
    static let option = KeyModifierFlags(rawValue: 1 << 3)

    /// Command modifier (⌘).
    static let command = KeyModifierFlags(rawValue: 1 << 4)

    /// Function (Fn) modifier.
    static let function = KeyModifierFlags(rawValue: 1 << 5)
}
