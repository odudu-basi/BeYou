import SwiftUI

struct OnboardingTemplate<Content: View>: View {
    let title: String
    let subtitle: String?
    let onNext: () -> Void
    let onBack: (() -> Void)?
    let buttonText: String
    let currentStep: Int?
    let totalSteps: Int
    let isNextEnabled: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        buttonText: String = "Continue",
        currentStep: Int? = nil,
        totalSteps: Int = 30,
        isNextEnabled: Bool = true,
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonText = buttonText
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.isNextEnabled = isNextEnabled
        self.onNext = onNext
        self.onBack = onBack
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            if let current = currentStep {
                ProgressBar(current: current, total: totalSteps)
            }

            // Back button
            HStack {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .font(.system(size: 20))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }

                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            Spacer()

            Button(action: onNext) {
                Text(buttonText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isNextEnabled ? .white : Color(hex: "B0B0B0"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isNextEnabled ? Color.black : Color(hex: "E8E8E8"))
                    .cornerRadius(16)
            }
            .disabled(!isNextEnabled)
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color(hex: "F8F8F8"))
    }
}
