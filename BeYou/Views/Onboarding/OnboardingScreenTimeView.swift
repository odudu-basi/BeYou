import SwiftUI

struct OnboardingScreenTimeView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedHours: Int = 4

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        OnboardingTemplate(
            title: "How much screen time do you average daily?",
            subtitle: "Be honest - this helps us help you",
            currentStep: currentStep,
            totalSteps: totalSteps,
            onNext: {
                appState.onboardingData.currentScreenTime = selectedHours
                onNext()
            },
            onBack: onBack
        ) {
            VStack(spacing: 30) {
                Text("\(selectedHours) hours")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)

                Slider(value: Binding(
                    get: { Double(selectedHours) },
                    set: { selectedHours = Int($0) }
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
            }
            .padding(.top, 40)
        }
    }
}
