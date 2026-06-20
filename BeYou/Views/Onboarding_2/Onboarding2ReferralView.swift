import SwiftUI

struct Onboarding2ReferralView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: (String) -> Void
    let onBack: (() -> Void)?

    @State private var selectedSource: String?

    private let sources: [(name: String, icon: String, isSystem: Bool)] = [
        ("TikTok", "tiktok_icon", false),
        ("YouTube", "youtube_icon", false),
        ("Instagram", "instagram_icon", false),
        ("App Store", "appstore_icon", false),
        ("Facebook", "facebook_icon", false),
        ("Google", "google_icon", false),
        ("X", "x_icon", false),
        ("Other", "ellipsis.bubble.fill", true)
    ]

    var body: some View {
        Onboarding2Template(
            title: "Where did you hear\nabout us?",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: selectedSource != nil,
            onNext: {
                if let source = selectedSource {
                    onNext(source)
                }
            },
            onBack: onBack
        ) {
            VStack(spacing: 10) {
                Spacer().frame(height: 12)

                ForEach(sources, id: \.name) { source in
                    Button(action: { selectedSource = source.name }) {
                        HStack(spacing: 14) {
                            if source.isSystem {
                                Image(systemName: source.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "666666"))
                                    .frame(width: 32, height: 32)
                            } else {
                                // Use SF symbol fallbacks since we may not have brand icons
                                referralIcon(for: source.name)
                                    .frame(width: 32, height: 32)
                            }

                            Text(source.name)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedSource == source.name ? Color.black : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(HapticButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func referralIcon(for name: String) -> some View {
        switch name {
        case "TikTok":
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case "YouTube":
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case "Instagram":
            Image(systemName: "camera.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case "App Store":
            Image(systemName: "app.badge.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case "Facebook":
            Image(systemName: "person.2.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color(hex: "1877F2"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case "Google":
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "4285F4"))
                .frame(width: 32, height: 32)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                )
        case "X":
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        default:
            Image(systemName: "ellipsis.bubble.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "666666"))
                .frame(width: 32, height: 32)
        }
    }
}
