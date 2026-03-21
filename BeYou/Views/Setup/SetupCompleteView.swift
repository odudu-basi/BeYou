import SwiftUI

struct SetupCompleteView: View {
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    // Logo tilted
                    Image("be-you-icon")
                        .resizable()
                        .frame(width: 90, height: 90)
                        .cornerRadius(22)
                        .rotationEffect(.degrees(-5))

                    VStack(spacing: 14) {
                        Text("You're all set!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .tracking(-0.3)

                        Text("Your setup is complete. We wish you the best as you aim to become the best version of yourself and live your life to the fullest — outside of mindless scrolling.")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "666666"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .padding(.horizontal, 8)
                    }

                    // Feedback nudge
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "6C5CE7"))

                        Text("Have feedback? Message us in the **Settings** tab. We read every message.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "888888"))
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
                    )
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)

                Spacer()

                Button(action: onNext) {
                    Text("Let's Go")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "1A1A1A"))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }
}
