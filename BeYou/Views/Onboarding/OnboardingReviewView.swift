import SwiftUI
import StoreKit

struct OnboardingReviewView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    @Environment(\.requestReview) private var requestReview

    private let reviews: [(name: String, title: String, body: String, color: Color)] = [
        ("Duke", "Great", "The app is one of the best I have seen!!", Color(hex: "6C5CE7")),
        ("Victor", "Great app", "It lives up to its expectation. It really helped me to reduce the amount of time I spend on X.com", Color(hex: "E17055")),
        ("Odudu", "Extremely essential", "Great useful app to help me stay focused on my daily tasks", Color(hex: "00B894")),
        ("Patrick", "INGENIOUS", "This is a very welcoming idea, to reshape the minds and restore the glory of the Youth to positive and mindful living", Color(hex: "0984E3"))
    ]

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()
                .onAppear {
                    AnalyticsManager.shared.track("Review Screen Shown")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        requestReview()
                    }
                }

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(spacing: 24) {
                        // Header with icon
                        HStack {
                            Text("Give us a rating")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Spacer()

                            Image("be-you-icon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .rotationEffect(.degrees(-10))
                        }
                        .padding(.top, 20)

                        // Mission statement
                        VStack(spacing: 16) {
                            Text("BeYou was made to help people improve their mental health and get off their phones")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)

                        }
                        .padding(.horizontal, 4)

                        // Review cards
                        VStack(spacing: 12) {
                            ForEach(reviews.indices, id: \.self) { index in
                                reviewCard(
                                    name: reviews[index].name,
                                    title: reviews[index].title,
                                    body: reviews[index].body,
                                    color: reviews[index].color
                                )
                            }
                        }

                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                // Continue button
                Button(action: {
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

    private func reviewCard(name: String, title: String, body: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Avatar with initial
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "666666"))
                }

                Spacer()

                // 5 stars
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "FFB800"))
                    }
                }
            }

            Text(body)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "666666"))
                .lineSpacing(3)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
        )
    }
}
