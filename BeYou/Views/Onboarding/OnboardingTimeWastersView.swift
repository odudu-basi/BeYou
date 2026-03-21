import SwiftUI

struct OnboardingTimeWastersView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedApps: Set<String> = []

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    let apps = [
        "Instagram",
        "TikTok",
        "Twitter/X",
        "Facebook",
        "YouTube",
        "Snapchat",
        "Reddit",
        "Netflix"
    ]

    var body: some View {
        OnboardingTemplate(
            title: "Which apps waste your time?",
            subtitle: "Select the biggest culprits",
            currentStep: currentStep,
            totalSteps: totalSteps,
            onNext: {
                appState.onboardingData.timeWasterApps = Array(selectedApps)
                // Also set these as apps for blocking with per-app intentions
                appState.onboardingData.selectedAppsForBlocking = Array(selectedApps)
                onNext()
            },
            onBack: onBack
        ) {
            VStack(spacing: 12) {
                ForEach(apps, id: \.self) { app in
                    SelectionCard(
                        title: app,
                        isSelected: selectedApps.contains(app)
                    ) {
                        if selectedApps.contains(app) {
                            selectedApps.remove(app)
                        } else {
                            selectedApps.insert(app)
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}
