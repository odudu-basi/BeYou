import SwiftUI

struct SetupFocusSessionView: View {
    @EnvironmentObject var appState: AppState
    @State private var disconnectTime = Date()

    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        OnboardingTemplate(
            title: "When should you disconnect?",
            subtitle: "Choose your peak focus time",
            onNext: {
                appState.onboardingData.disconnectSchedule.startTime = disconnectTime
                onNext()
            },
            onBack: onBack
        ) {
            VStack(spacing: 30) {
                DatePicker("Disconnect Time", selection: $disconnectTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                VStack(spacing: 8) {
                    Text("Apps will be restricted at")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Text(disconnectTime, style: .time)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .padding(.top, 40)
        }
    }
}
