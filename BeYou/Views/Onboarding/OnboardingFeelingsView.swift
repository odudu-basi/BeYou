import SwiftUI

struct OnboardingFeelingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFeelings: Set<String> = []

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    let feelings = [
        ("Irritable", "irritable"),
        ("Not Present", "not-present"),
        ("Mentally Drained", "drained"),
        ("Regretful or Guilty", "regretful"),
        ("Empty or Hollow", "empty"),
        ("Powerless", "powerless")
    ]

    var body: some View {
        OnboardingTemplate(
            title: "How does using these apps for too long make you feel?",
            subtitle: "Choose up to 2",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: !selectedFeelings.isEmpty,
            onNext: {
                appState.onboardingData.feelings = Array(selectedFeelings)
                onNext()
            },
            onBack: onBack
        ) {
            VStack(spacing: 12) {
                ForEach(feelings, id: \.1) { feeling in
                    SelectionCard(
                        title: feeling.0,
                        isSelected: selectedFeelings.contains(feeling.1)
                    ) {
                        if selectedFeelings.contains(feeling.1) {
                            selectedFeelings.remove(feeling.1)
                        } else {
                            if selectedFeelings.count < 2 {
                                selectedFeelings.insert(feeling.1)
                            }
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}
