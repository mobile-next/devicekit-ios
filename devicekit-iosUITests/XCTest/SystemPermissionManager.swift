import XCTest

// MARK: - Permission Value

/// Represents the configured action for a system permission dialog.
///
/// Used to configure automatic handling of system permission alerts.
///
/// ## Configuration
/// Permissions are configured via UserDefaults with the key `"permissions"`:
/// ```swift
/// let permissions = ["notifications": "allow"]
/// let data = try JSONEncoder().encode(permissions)
/// UserDefaults.standard.set(data, forKey: "permissions")
/// ```
enum PermissionValue: String, Codable {
    /// Automatically tap "Allow" on the permission dialog.
    case allow

    /// Automatically tap "Don't Allow" on the permission dialog.
    case deny

    /// Do not interact with the permission dialog.
    case unset

    /// Unknown or unrecognized permission value.
    case unknown

    init(from decoder: Decoder) throws {
        self =
            try PermissionValue(
                rawValue: decoder.singleValueContainer().decode(RawValue.self)
            ) ?? .unknown
    }
}

// MARK: - System Permission Helper

/// Handles automatic dismissal of system permission dialogs.
///
/// This helper automatically taps "Allow" or "Don't Allow" buttons on system
/// permission dialogs based on configuration stored in UserDefaults.
///
/// ## Configuration
/// Set permissions via UserDefaults with key `"permissions"`:
/// ```json
/// {
///   "notifications": "allow"
/// }
/// ```
///
/// ## Supported Permissions
/// - `notifications`: Push notification permission dialog
///
/// ## Usage
/// ```swift
/// SystemPermissionManager.handleSystemPermissionAlertIfNeeded(foregroundApp: app)
/// ```
final class SystemPermissionManager {

    /// Label text used to identify notification permission alerts.
    private static let notificationsPermissionLabel =
        "Would Like to Send You Notifications"

    /// Handles system permission alerts if configured.
    ///
    /// This method checks for notification permission dialogs and automatically
    /// taps the appropriate button based on UserDefaults configuration.
    ///
    /// - Parameter foregroundApp: The application to check for permission dialogs.
    ///
    /// - Note: Only handles alerts when SpringBoard is the foreground app.
    static func handleSystemPermissionAlertIfNeeded(
        foregroundApp: XCUIApplication
    ) {
        let predicate = NSPredicate(
            format: "label CONTAINS[c] %@",
            notificationsPermissionLabel
        )

        guard
            let data = UserDefaults.standard.object(forKey: "permissions")
                as? Data,
            let permissions = try? JSONDecoder().decode(
                [String: PermissionValue].self,
                from: data
            ),
            let notificationsPermission = permissions.first(where: {
                $0.key == "notifications"
            })
        else {
            return
        }

        if foregroundApp.bundleID != "com.apple.springboard" {
            NSLog(
                "Foreground app is not springboard skipping auto tapping on permissions"
            )
            return
        }

        NSLog(
            "[Start] Foreground app is springboard attempting to tap on permissions dialog"
        )
        let alert = foregroundApp.alerts.matching(predicate).element
        if alert.exists {
            switch notificationsPermission.value {
            case .allow:
                let allowButton = alert.buttons.element(boundBy: 1)
                if allowButton.exists {
                    allowButton.tap()
                }
            case .deny:
                let dontAllowButton = alert.buttons.element(boundBy: 0)
                if dontAllowButton.exists {
                    dontAllowButton.tap()
                }
            case .unset, .unknown:
                // do nothing
                break
            }
        }
        NSLog(
            "[Done] Foreground app is springboard attempting to tap on permissions dialog"
        )
    }
}
