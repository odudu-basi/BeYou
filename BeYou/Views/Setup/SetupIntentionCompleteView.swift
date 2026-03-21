import SwiftUI

struct SetupIntentionCompleteView: View {
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 40)

                        // Celebration
                        Text("\u{1F389}")
                            .font(.system(size: 64))

                        VStack(spacing: 12) {
                            Text("Your first app intention is set!")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                                .multilineTextAlignment(.center)

                            Text("Nice work! Here's how it works")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "999999"))
                        }

                        // How it works cards
                        VStack(spacing: 16) {
                            howItWorksCard(
                                number: "1",
                                title: "You open a blocked app",
                                description: "When you try to open an app you've set an intention for, a mindful pause will appear."
                            )

                            howItWorksCard(
                                number: "2",
                                title: "Read through your affirmations",
                                description: "Take a moment to reflect on a few positive affirmations before continuing. This small pause makes a big difference."
                            )

                            howItWorksCard(
                                number: "3",
                                title: "The app unlocks for a session",
                                description: "After your mindful moment, you'll get a timed session to use the app. Once it's up, the cycle starts fresh."
                            )
                        }

                        // Tip card
                        HStack(spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "F5A623"))

                            Text("You can add more app intentions anytime from the Home tab.")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "666666"))
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(Color(hex: "FFF8EC"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "F5E6C8"), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

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

    private func howItWorksCard(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color(hex: "6C5CE7"))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "888888"))
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
        )
    }
}
