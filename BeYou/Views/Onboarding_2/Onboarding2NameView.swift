import SwiftUI

/// Asks the user for their name — first step after the welcome screen.
struct Onboarding2NameView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: (String) -> Void
    let onBack: (() -> Void)?

    @State private var name: String
    @FocusState private var focused: Bool

    init(initialName: String = "",
         currentStep: Int,
         totalSteps: Int,
         onNext: @escaping (String) -> Void,
         onBack: (() -> Void)?) {
        _name = State(initialValue: initialName)
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onNext = onNext
        self.onBack = onBack
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Onboarding2Template(
            title: "What's your name?",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: !trimmedName.isEmpty,
            onNext: { onNext(trimmedName) },
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("We use your name to personalize the app for you.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "888888"))

                TextField("Your name", text: $name)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .focused($focused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                    )
                    .onSubmit {
                        if !trimmedName.isEmpty { onNext(trimmedName) }
                    }

                Spacer()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
            }
        }
    }
}
