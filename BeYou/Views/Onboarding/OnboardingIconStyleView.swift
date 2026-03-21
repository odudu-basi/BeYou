import SwiftUI

struct OnboardingIconStyleView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedStyle: String = "Default"
    @State private var showingIconAlert = false

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    // Default icon first, then alternates
    let styles: [(name: String, imageName: String, iconName: String?)] = [
        ("Default", "be-you-icon", nil), // nil = primary icon
        ("Blush", "be-you-1-blush", "be-you-1-blush"),
        ("Celestial", "be-you-2-celestial", "be-you-2-celestial"),
        ("Holographic", "be-you-3-holographic", "be-you-3-holographic"),
        ("Starfield", "be-you-4-starfield", "be-you-4-starfield"),
        ("Clouds", "be-you-5-clouds", "be-you-5-clouds"),
        ("Aurora", "be-you-6-aurora", "be-you-6-aurora"),
        ("Peach Lavender", "be-you-7-peach-lavender", "be-you-7-peach-lavender"),
        ("Cream Spark", "be-you-8-cream-spark", "be-you-8-cream-spark"),
        ("Slate Navy", "be-you-9-slate-navy", "be-you-9-slate-navy")
    ]

    var body: some View {
        OnboardingTemplate(
            title: "Choose your app icon",
            subtitle: "Pick a style that resonates with you",
            currentStep: currentStep,
            totalSteps: totalSteps,
            onNext: {
                appState.onboardingData.iconStyle = selectedStyle
                onNext()
            },
            onBack: onBack
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(styles, id: \.name) { style in
                    VStack(spacing: 8) {
                        Image(style.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedStyle == style.name ? Color.black : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                selectedStyle = style.name
                                changeAppIcon(to: style.iconName)
                            }

                        Text(style.name)
                            .font(.system(size: 12, weight: selectedStyle == style.name ? .semibold : .regular))
                            .foregroundColor(selectedStyle == style.name ? Color(hex: "1A1A1A") : .gray)
                    }
                }
            }
            .padding(.top, 20)
        }
    }

    private func changeAppIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Failed to change app icon: \(error.localizedDescription)")
            }
        }
    }
}
