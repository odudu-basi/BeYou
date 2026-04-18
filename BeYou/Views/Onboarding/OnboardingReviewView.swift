import SwiftUI
import StoreKit

struct OnboardingReviewView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    @Environment(\.requestReview) private var requestReview
    @State private var hasTappedSupportButton = false

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(spacing: 28) {
                        // Heart icon
                        Text("\u{1F331}")
                            .font(.system(size: 56))
                            .padding(.top, 28)

                        // Mission statement
                        VStack(spacing: 14) {
                            Text("You're not alone in this")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                                .multilineTextAlignment(.center)

                            Text("Every day, billions of people open apps designed to keep them scrolling — not because they want to, but because the apps are built that way.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color(hex: "666666"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                        }
                        .padding(.horizontal, 8)

                        // Stats card
                        VStack(spacing: 16) {
                            HStack(spacing: 0) {
                                statBubble(number: "4.8", label: "hrs/day", detail: "Average person's\nscreen time")
                                Spacer()
                                Rectangle()
                                    .fill(Color(hex: "EBEBEB"))
                                    .frame(width: 1, height: 50)
                                Spacer()
                                statBubble(number: "50%", label: "of users", detail: "Feel worse after\nlong scrolling")
                                Spacer()
                                Rectangle()
                                    .fill(Color(hex: "EBEBEB"))
                                    .frame(width: 1, height: 50)
                                Spacer()
                                statBubble(number: "1 in 3", label: "people", detail: "Want to cut down\nbut can't")
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
                        )

                        // Mission card
                        VStack(spacing: 14) {
                            Text("We built BeYou for this exact reason")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .multilineTextAlignment(.center)

                            Text("Our small team is on a mission to help people take back their time, protect their mental health, and start living the life they actually want — not the one algorithms chose for them.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(hex: "666666"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)

                            Text("A quick rating helps more people find us and join the movement. It takes 5 seconds and means the world to us.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(hex: "999999"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "F0EDFF"))
                        )

                        // Rate button
                        Button(action: {
                            hasTappedSupportButton = true
                            requestReview()
                            AnalyticsManager.shared.track("Review Prompt Requested")
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16))
                                Text(hasTappedSupportButton ? "Thank you!" : "Support Our Mission")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "6C5CE7"), Color(hex: "8B7CF7")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                        }
                        .disabled(hasTappedSupportButton)
                        .opacity(hasTappedSupportButton ? 0.7 : 1.0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                // Continue button
                Button(action: {
                    if !hasTappedSupportButton {
                        requestReview()
                    }
                    onNext()
                }) {
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

    private func statBubble(number: String, label: String, detail: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "6C5CE7"))
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "999999"))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

}
