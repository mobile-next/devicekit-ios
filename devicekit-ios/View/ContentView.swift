import SwiftUI

/// The main SwiftUI view that presents the automatic ReplayKit broadcast launcher.
///
/// `ContentView` serves as the entry point of the UI. It embeds
/// `BroadcastStarterView`, which wraps and auto‑activates the system
/// `RPSystemBroadcastPickerView` to begin a ReplayKit broadcast as soon as the
/// interface appears.
///
/// ## Responsibilities
/// - Fill the available screen space.
/// - Provide a dark background suitable for a minimal, unobtrusive UI.
/// - Host `BroadcastStarterView`, which handles all broadcast‑related logic.
///
/// ## Usage
/// This view is typically used as the root view of the app:
///
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///         }
///     }
/// }
/// ```
///
/// When the view appears, the broadcast picker is automatically triggered,
/// starting the ReplayKit broadcast without requiring user interaction.
struct ContentView: View {
    var body: some View {
        BroadcastStarterView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
}
