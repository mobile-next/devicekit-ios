import ReplayKit
import SwiftUI

/// A SwiftUI view that automatically launches the ReplayKit broadcast picker
/// and programmatically taps its internal button to start a broadcast session.
///
/// `BroadcastStarterView` is designed for apps that want to begin a ReplayKit
/// broadcast immediately when the view appears, without requiring the user to
/// manually tap the system‑provided `RPSystemBroadcastPickerView`.
///
/// ## How It Works
/// - Embeds a `BroadcastPickerView` (a SwiftUI wrapper around
///   `RPSystemBroadcastPickerView`).
/// - On appearance, searches the UIKit view hierarchy for the underlying picker.
/// - Locates the internal `UIButton` inside the picker.
/// - Programmatically triggers `.touchUpInside` to simulate a user tap.
///
/// ## Why This Is Necessary
/// ReplayKit does not expose a SwiftUI‑native broadcast API.
/// The only supported way to start a broadcast is through the system picker,
/// which is a UIKit view. SwiftUI apps must wrap and interact with it manually.
///
/// ## Important Notes
/// - This approach relies on UIKit view traversal, which Apple does not formally
///   guarantee but is widely used in ReplayKit integrations.
/// - The auto‑tap occurs asynchronously on the main queue to ensure the picker
///   has been inserted into the window hierarchy.
/// - The broadcast extension identifier must match the one declared in your
///   Broadcast Upload Extension target.
///
/// ## Usage
/// ```swift
/// BroadcastStarterView()
///     .frame(width: 80, height: 80)
/// ```
///
/// When the view appears, the broadcast picker button is automatically tapped.
struct BroadcastStarterView: View {

    /// The bundle identifier of the ReplayKit Broadcast Upload Extension.
    let preferredExtension =
        "com.mobilenext.devicekit-ios.BroadcastUploadExtension"

    var body: some View {
        BroadcastPickerView(preferredExtension: preferredExtension)
            .frame(width: 80, height: 80)
            .onAppear {
                autoTapPickerButton()
            }
    }

    /// Attempts to locate the underlying `RPSystemBroadcastPickerView` in the
    /// UIKit view hierarchy and simulate a tap on its internal button.
    ///
    /// This method:
    /// - Retrieves the active window.
    /// - Recursively searches for the broadcast picker.
    /// - Sends `.touchUpInside` to the picker's button.
    private func autoTapPickerButton() {
        DispatchQueue.main.async {
            guard
                let windowScene = UIApplication.shared.connectedScenes.first
                    as? UIWindowScene,
                let window = windowScene.windows.first,
                let picker = findPicker(in: window)
            else {
                return
            }

            if let button = picker.subviews.first as? UIButton {
                button.sendActions(for: .touchUpInside)
            }
        }
    }

    /// Recursively searches a view hierarchy for an `RPSystemBroadcastPickerView`.
    ///
    /// - Parameter view: The root view to search.
    /// - Returns: The first matching picker, or `nil` if none is found.
    private func findPicker(in view: UIView) -> RPSystemBroadcastPickerView? {
        if let picker = view as? RPSystemBroadcastPickerView {
            return picker
        }
        for subview in view.subviews {
            if let found = findPicker(in: subview) {
                return found
            }
        }
        return nil
    }
}
