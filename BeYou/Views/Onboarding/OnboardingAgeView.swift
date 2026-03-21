import SwiftUI

struct OnboardingAgeView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedAgeRange: String?

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    let ageRanges = [
        "Under 18",
        "18-24",
        "25-29",
        "30-40",
        "40 and over"
    ]

    var body: some View {
        OnboardingTemplate(
            title: "How old are you?",
            subtitle: "Choose one",
            currentStep: currentStep,
            totalSteps: totalSteps,
            onNext: {
                if let range = selectedAgeRange {
                    // Save the midpoint of the range for calculation purposes
                    let ageValue: Int
                    switch range {
                    case "Under 18": ageValue = 16
                    case "18-24": ageValue = 21
                    case "25-29": ageValue = 27
                    case "30-40": ageValue = 35
                    case "40 and over": ageValue = 45
                    default: ageValue = 25
                    }
                    appState.onboardingData.age = ageValue
                    onNext()
                }
            },
            onBack: onBack
        ) {
            VStack(spacing: 12) {
                ForEach(ageRanges, id: \.self) { range in
                    SelectionCard(
                        title: range,
                        isSelected: selectedAgeRange == range
                    ) {
                        selectedAgeRange = range
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}
