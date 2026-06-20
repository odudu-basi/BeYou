import SwiftUI
import UIKit

/// Lightweight tap haptic used across the app for a more tactile feel.
enum Haptics {
    private static let generator = UIImpactFeedbackGenerator(style: .light)

    /// A subtle tap — call on any custom tap target (e.g. `.onTapGesture`).
    static func tap() {
        generator.impactOccurred()
    }
}

/// Button style that fires a light haptic on press and dims slightly, while
/// otherwise rendering the label exactly as-is (like `.plain`). Used as the
/// app-wide default so every button feels tactile.
struct HapticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed { Haptics.tap() }
            }
    }
}
