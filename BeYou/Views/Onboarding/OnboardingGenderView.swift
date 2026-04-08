import SwiftUI

struct OnboardingGenderView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedGender: String?

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    let genders = ["Male", "Female", "Prefer not to say"]

    var body: some View {
        OnboardingTemplate(
            title: "How do you identify?",
            subtitle: "This helps us personalize your affirmations",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: selectedGender != nil,
            onNext: {
                if let gender = selectedGender {
                    appState.onboardingData.gender = gender
                    onNext()
                }
            },
            onBack: onBack
        ) {
            VStack(spacing: 12) {
                ForEach(genders, id: \.self) { gender in
                    SelectionCard(
                        title: gender,
                        isSelected: selectedGender == gender
                    ) {
                        selectedGender = gender
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}
