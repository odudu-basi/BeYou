import SwiftUI
import StoreKit

struct Onboarding2RatingView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    @Environment(\.requestReview) private var requestReview

    private let reviews = [
        (name: "Victor", title: "Life Changing", text: "This app completely transformed my mornings. I actually wake up and stay up now.", stars: 5),
        (name: "Duke", title: "No More Snoozing", text: "I used to set 5 alarms. Now I only need one. BeYou actually holds me accountable.", stars: 5),
        (name: "Odudu", title: "Exactly What I Needed", text: "The positive affirmations in the morning set the tone for my entire day. Highly recommend.", stars: 5),
        (name: "Patrick", title: "INGENIOUS", text: "This is a very welcoming idea, to reshape the minds and restore the glory of the Youth to positive and mindful living.", stars: 5),
    ]

    var body: some View {
        Onboarding2Template(
            title: "",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: true,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 16) {
                Spacer().frame(height: 8)

                Text("Give us a rating")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                // Stars
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "FFB800"))
                    }
                }

                Text("This app was designed for\npeople like you.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .multilineTextAlignment(.center)

                // Review cards
                ForEach(reviews, id: \.name) { review in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(0..<review.stars, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "FFB800"))
                            }
                        }

                        Text(review.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))

                        Text(review.text)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "666666"))
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(14)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                requestReview()
            }
        }
    }
}
