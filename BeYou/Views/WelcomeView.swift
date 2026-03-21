import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Logo top-left, tilted
                Image("be-you-icon")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .cornerRadius(18)
                    .rotationEffect(.degrees(-8))
                    .padding(.top, 60)
                    .padding(.leading, 28)

                Spacer().frame(height: 40)

                // Title
                VStack(alignment: .leading, spacing: 16) {
                    Text("Take back your time.\nBecome who you're\nmeant to be.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .lineSpacing(4)
                        .tracking(-0.5)

                    Text("Your screen time shapes your mindset more than you think. BeYou helps you build real discipline, break free from mindless scrolling, and start believing in your potential again.")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "666666"))
                        .lineSpacing(6)
                }
                .padding(.horizontal, 28)

                Spacer()

                // Get Started button
                Button(action: {
                    appState.navigateTo(.onboarding)
                }) {
                    Text("Get Started")
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
