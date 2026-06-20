import SwiftUI

struct Onboarding2WelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("BeYou Alarm")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()

            Image("be-you-4-starfield")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .cornerRadius(22)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome!")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text("Never snooze again. Finally get up on time, start your day with positivity, and become the best version of yourself.")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(hex: "888888"))
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer()
            Spacer()

            // Get Started button
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color(hex: "F8F8F8"))
    }
}
