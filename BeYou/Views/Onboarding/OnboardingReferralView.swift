import SwiftUI

struct OnboardingReferralView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedOption: String?

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    let options = [
        "TikTok",
        "Instagram",
        "Reddit",
        "X",
        "App Store",
        "Friend or family",
        "Other"
    ]

    var body: some View {
        OnboardingTemplate(
            title: "How did you hear about us?",
            subtitle: "Help us understand how you discovered BeYou",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: selectedOption != nil,
            onNext: {
                if let selection = selectedOption {
                    appState.onboardingData.referral = selection
                    onNext()
                }
            },
            onBack: onBack
        ) {
            VStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    SelectionCard(
                        title: option,
                        isSelected: selectedOption == option
                    ) {
                        selectedOption = option
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}
