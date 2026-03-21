import SwiftUI

struct SetupDailyGoalView: View {
    @EnvironmentObject var appState: AppState
    @State private var goalHours: Int = 2

    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        OnboardingTemplate(
            title: "Set your daily goal",
            subtitle: "How much time do you want to spend on selected apps?",
            onNext: {
                appState.onboardingData.dailyGoal = "\(goalHours) hours"
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
                ), in: 0...8, step: 1)
                    .accentColor(.black)

                HStack {
                    Text("0h")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("8h+")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 40)
        }
    }
}
