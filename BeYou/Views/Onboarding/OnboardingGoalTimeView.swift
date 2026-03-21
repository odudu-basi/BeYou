import SwiftUI

struct OnboardingGoalTimeView: View {
    @EnvironmentObject var appState: AppState
    @State private var goalHours: Int = 2

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        OnboardingTemplate(
            title: "What's your goal screen time?",
            subtitle: "Let's set a realistic target, \(appState.onboardingData.name ?? "")",
            currentStep: currentStep,
            totalSteps: totalSteps,
            onNext: {
                appState.onboardingData.goalTime = goalHours
                onNext()
            },
            onBack: onBack
        ) {
            VStack(spacing: 30) {
                Text("\(goalHours) hours")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)

                Slider(value: Binding(
                    get: { Double(goalHours) },
                    set: { goalHours = Int($0) }
                ), in: 0...12, step: 1)
                    .accentColor(.black)

                HStack {
                    Text("0h")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("12h+")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                if let current = appState.onboardingData.currentScreenTime, current > goalHours {
                    VStack(spacing: 8) {
                        Text("That's \(current - goalHours) hours less per day")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)

                        Text("= \((current - goalHours) * 7) hours saved per week!")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.top, 40)
        }
    }
}
