import SwiftUI

struct OnboardingAffirmationsInfoView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                Spacer()

                VStack(spacing: 0) {
                    Text("\"")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .lineLimit(1)
                        .padding(.bottom, 8)

                    Text("Affirmations are short\nphrases you repeat to\nyourself")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .multilineTextAlignment(.center)
                        .tracking(-0.3)
                        .lineSpacing(10)
                        .padding(.bottom, 20)

                    Text("They reshape your mindset, build confidence,\nand help you stay aligned with your goals.")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "999999"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(7)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Bottom button
                Button(action: onNext) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "1A1A1A"))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 12)
            }
        }
    }
}
