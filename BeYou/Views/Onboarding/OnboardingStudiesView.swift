import SwiftUI

struct OnboardingStudiesView: View {
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

                VStack(spacing: 28) {
                    Text("📖")
                        .font(.system(size: 56))

                    Text("Studies show daily affirmations boost self-confidence, resilience, and overall well-being")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .multilineTextAlignment(.center)
                        .tracking(-0.3)
                        .lineSpacing(10)
                }
                .padding(.horizontal, 36)

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
