import SwiftUI

struct OnboardingGoalsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedGoals: Set<String> = []

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    let goals = [
        "Reduce screen time",
        "Be more present",
        "Improve focus",
        "Better sleep",
        "More productive",
        "Reduce anxiety"
    ]

    var body: some View {
        OnboardingTemplate(
            title: "What are your goals, \(appState.onboardingData.name ?? "there")?",
            subtitle: "Select all that apply",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: !selectedGoals.isEmpty,
            onNext: {
                appState.onboardingData.goals = Array(selectedGoals)
                onNext()
            },
            onBack: onBack
        ) {
            VStack(spacing: 12) {
                ForEach(goals, id: \.self) { goal in
                    SelectionCard(
                        title: goal,
                        isSelected: selectedGoals.contains(goal)
                    ) {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}
