import Foundation

// MARK: - DumpUI Request Model

/// Request body for the `/dumpUI` endpoint.
///
/// This model represents the JSON payload for capturing the UI view hierarchy.
///
/// ## JSON Format
/// ```json
/// {
///   "appIds": [],
///   "excludeKeyboardElements": false
/// }
/// ```
///
/// ## curl Examples
/// ```bash
/// # Capture full UI hierarchy
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": false}'
///
/// # Exclude keyboard from hierarchy
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": true}'
///
/// # Pretty-print JSON output
/// curl -X POST http://127.0.0.1:12004/dumpUI \
///     -H "Content-Type: application/json" \
///     -d '{"appIds": [], "excludeKeyboardElements": false}' | jq .
/// ```
struct DumpUIRequest: Codable {

    /// Array of bundle identifiers to target.
    /// - Empty array `[]`: Captures the current foreground application.
    /// - Specific IDs: Targets the specified applications.
    let appIds: [String]

    /// Whether to exclude keyboard UI elements from the hierarchy.
    /// - `true`: Filters out all keyboard-related elements.
    /// - `false`: Includes keyboard elements in the response.
    let excludeKeyboardElements: Bool
}
