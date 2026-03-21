import SwiftUI

struct OnboardingCategoriesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategories: Set<String> = []

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    let categories = [
        "Anxiety",
        "Morning",
        "Feeling sassy",
        "Self-love",
        "Overthinking",
        "Attraction",
        "Gratitude",
        "Purpose",
        "Dream big",
        "Confidence",
        "Self-talk",
        "Positivity",
        "Romance",
        "Inner child"
    ]

    var body: some View {
        OnboardingTemplate(
            title: "Choose your affirmation categories",
            subtitle: "Select what you want to focus on",
            currentStep: currentStep,
            totalSteps: totalSteps,
            onNext: {
                appState.onboardingData.categories = Array(selectedCategories)
                onNext()
            },
            onBack: onBack
        ) {
            VStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    SelectionCard(
                        title: category,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}
