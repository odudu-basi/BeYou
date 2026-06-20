import SwiftUI

// MARK: - "It's not a discipline problem" Screen

struct Onboarding2DisciplineView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        Onboarding2Template(
            title: "",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: true,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                Spacer().frame(height: 60)

                // Brain icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "FFE0F0"))
                        .frame(width: 120, height: 120)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50))
                        .foregroundColor(Color(hex: "FF6B9D"))
                }

                Spacer().frame(height: 20)

                Text("It's not a discipline\nproblem")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .multilineTextAlignment(.center)

                Text("You aren't lazy. You are fighting biology. When the alarm rings, your brain's prefrontal cortex (the self-control part) is offline. This sleep inertia makes snoozing feel like the only decision.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "888888"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
        }
    }
}

// MARK: - "Waking up at X is a realistic target" Screen

struct Onboarding2RealisticTargetView: View {
    let currentStep: Int
    let totalSteps: Int
    let selectedTime: String
    let onNext: () -> Void
    let onBack: (() -> Void)?

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
                Spacer().frame(height: 100)

                (
                    Text("Waking up at ")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                    +
                    Text(selectedTime)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "E8A87C"))
                    +
                    Text(" is a realistic target. It's not hard at all!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                )
                .multilineTextAlignment(.center)

                Text("90% of users say that they wake up on time after using BeYou.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "888888"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
        }
    }
}

// MARK: - "Wake the body to wake the mind" Screen

struct Onboarding2WakeBodyView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        Onboarding2Template(
            title: "",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: true,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                Spacer().frame(height: 40)

                // Exercise illustration (using SF Symbol)
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "E8F8F5"))
                        .frame(width: 200, height: 140)

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }

                Spacer().frame(height: 20)

                Text("Wake the body to wake\nthe mind")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .multilineTextAlignment(.center)

                Text("Physical movement spikes cortisol (the wake-up hormone) and clears sleep inertia instantly. By the time the alarm is off, you are fully awake.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "888888"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
        }
    }
}
