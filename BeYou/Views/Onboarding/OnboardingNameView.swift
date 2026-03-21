import SwiftUI

struct OnboardingNameView: View {
    @EnvironmentObject var appState: AppState
    @State private var name: String = ""

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        OnboardingTemplate(
            title: "What's your name?",
            subtitle: "We'll personalize your experience",
            currentStep: currentStep,
            totalSteps: totalSteps,
            onNext: {
                if !name.isEmpty {
                    appState.onboardingData.name = name
                    onNext()
                }
            },
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("First Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)

                TextField("Enter your name", text: $name)
                    .font(.system(size: 17))
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .padding(.top, 20)
        }
    }
}
