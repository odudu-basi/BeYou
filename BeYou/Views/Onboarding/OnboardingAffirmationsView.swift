import SwiftUI

struct OnboardingAffirmationsView: View {
    @EnvironmentObject var appState: AppState
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private let stats = [
        (value: "80%", description: "of people who use daily affirmations report feeling more confident and motivated within 30 days."),
        (value: "3x", description: "more likely to achieve goals when you pair intention with positive self-talk."),
        (value: "67%", description: "reduction in negative thought patterns reported by consistent affirmation practitioners.")
    ]

    private let benefits = [
        (icon: "🎯", title: "Stick to Your Goals", text: "Affirmations rewire your brain to stay focused on what truly matters to you."),
        (icon: "🔥", title: "Build Momentum", text: "Starting each day with intention creates a compound effect on your habits."),
        (icon: "🌱", title: "Become Your Best Self", text: "Consistently speaking your identity into existence shapes who you become.")
    ]

    private var userName: String {
        appState.onboardingData.name ?? "there"
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("One more thing, \(userName)...")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))

                            Text("The Power of\nAffirmations")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                                .lineSpacing(8)
                                .padding(.bottom, 12)

                            Text("Science-backed words that reshape how you think, act, and show up every day.")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "666666"))
                                .lineSpacing(7)
                        }
                        .padding(.top, 28)
                        .padding(.bottom, 32)

                        // Stats
                        VStack(spacing: 12) {
                            ForEach(0..<stats.count, id: \.self) { index in
                                HStack(spacing: 16) {
                                    Text(stats[index].value)
                                        .font(.system(size: 32, weight: .heavy))
                                        .foregroundColor(Color(hex: "4CAF50"))
                                        .frame(minWidth: 70, alignment: .leading)

                                    Text(stats[index].description)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "BBBBBB"))
                                        .lineSpacing(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 20)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "1A1A1A"))
                                .cornerRadius(16)
                            }
                        }
                        .padding(.bottom, 32)

                        // Benefits Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("How affirmations help you")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            ForEach(0..<benefits.count, id: \.self) { index in
                                HStack(alignment: .top, spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "F0F0F0"))
                                            .frame(width: 44, height: 44)

                                        Text(benefits[index].icon)
                                            .font(.system(size: 22))
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(benefits[index].title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "1A1A1A"))

                                        Text(benefits[index].text)
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "666666"))
                                            .lineSpacing(6)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(18)
                                .background(Color.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
                                )
                            }
                        }
                        .padding(.bottom, 28)

                        // Quote Card
                        VStack(spacing: 14) {
                            Text("\"I am not what happened to me.\nI am what I choose to become.\"")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .italic()
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)

                            Text("— Carl Jung")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "888888"))
                        }
                        .padding(.vertical, 28)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "1A1A1A"))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }

                // Bottom button
                Button(action: onNext) {
                    Text("I'm Ready")
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
