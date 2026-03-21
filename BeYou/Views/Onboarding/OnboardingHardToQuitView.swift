import SwiftUI

struct OnboardingHardToQuitView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedReasons: Set<String> = []

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    let reasons = [
        "I don't want to miss out on what's happening",
        "The endless scroll just keeps me hooked",
        "I reach for it without even thinking",
        "It fills the quiet or boring moments",
        "I use it to avoid things I should be doing",
        "It helps me relax or escape stress",
        "I enjoy the content and don't want to stop",
        "Notifications keep pulling me back in"
    ]

    var body: some View {
        OnboardingTemplate(
            title: "What keeps pulling you back?",
            subtitle: "Pick up to 4 — understanding your patterns is the first step to changing them.",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: !selectedReasons.isEmpty,
            onNext: {
                appState.onboardingData.hardToQuitReasons = Array(selectedReasons)
                onNext()
            },
            onBack: onBack
        ) {
            VStack(spacing: 12) {
                ForEach(reasons, id: \.self) { reason in
                    SelectionCard(
                        title: reason,
                        isSelected: selectedReasons.contains(reason)
                    ) {
                        if selectedReasons.contains(reason) {
                            selectedReasons.remove(reason)
                        } else {
                            if selectedReasons.count < 4 {
                                selectedReasons.insert(reason)
                            }
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}
