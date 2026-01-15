import ReplayKit
import SwiftUI

/// A SwiftUI wrapper for `RPSystemBroadcastPickerView`, the system‑provided UI
/// used to start and stop ReplayKit broadcast uploads.
///
/// `BroadcastPickerView` embeds the UIKit broadcast picker inside SwiftUI using
/// `UIViewRepresentable`. This allows SwiftUI apps to trigger a broadcast
/// extension without manually presenting UIKit controllers.
///
/// ## Features
/// - Wraps `RPSystemBroadcastPickerView` for use in SwiftUI.
/// - Automatically applies the desired broadcast extension identifier.
/// - Allows tinting the internal button to match app styling.
///
/// ## Usage
/// ```swift
/// BroadcastPickerView(preferredExtension: "com.example.MyBroadcastExtension")
///     .frame(width: 80, height: 80)
/// ```
///
/// ## Important Notes
/// - ReplayKit does not expose a SwiftUI-native broadcast picker; wrapping is required.
/// - The internal button is a private subview of the picker. Accessing it is safe,
///   but Apple does not guarantee its structure across OS versions.
/// - `updateUIView` is intentionally empty because the picker does not require
///   dynamic updates once created.
struct BroadcastPickerView: UIViewRepresentable {
    /// The bundle identifier of the broadcast upload extension to launch.
    let preferredExtension: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 80,
                height: 80
            )
        )
        picker.preferredExtension = preferredExtension

        // Tint the internal button to match the desired UI theme.
        if let button = picker.subviews.first as? UIButton {
            button.imageView?.tintColor = .white
        }

        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        // No dynamic updates required.
    }
}
