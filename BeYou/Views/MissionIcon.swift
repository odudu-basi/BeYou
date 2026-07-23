import SwiftUI

/// Renders a mission's icon at a given point `size`, inheriting the caller's `.foregroundColor`.
///
/// Most missions use SF Symbols. "Push Ups" uses a custom template asset ("pushups") because
/// SF Symbols has no push-up glyph — the closest fitness symbols read as core/plank poses, not
/// push-ups. The custom asset is a template image, so it tints and scales just like the symbols,
/// letting every call site keep its own tint / background / sizing unchanged.
struct MissionIcon: View {
    let mission: String
    /// The SF Symbol to use when this isn't the custom push-up case.
    let systemName: String
    let size: CGFloat
    /// When true, the custom push-up art renders in its ORIGINAL colors (white figure + faded
    /// ground) — used on the colored circle in the challenge picker for the two-tone look. When
    /// false it renders as a template and inherits the caller's `.foregroundColor` like the symbols.
    var twoTone: Bool = false

    var body: some View {
        if mission == "Push Ups" {
            Image("pushups")
                .renderingMode(twoTone ? .original : .template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: systemName)
                .font(.system(size: size))
        }
    }
}
