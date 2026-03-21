import SwiftUI

@available(iOS 16.0, *)
struct SetupAllowedAppsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager

    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        OnboardingTemplate(
            title: "Review & Activate",
            subtitle: "Ready to start your journey?",
            buttonText: "Start BeYou",
            onNext: {
                // Apply the Screen Time restrictions
                screenTimeManager.blockSelectedApps()
                onNext()
            },
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                InfoCard(
                    icon: "app.badge.checkmark",
                    title: "Apps Selected",
                    description: "You've chosen apps to manage"
                )

                InfoCard(
                    icon: "target",
                    title: "Daily Goal Set",
                    description: appState.onboardingData.dailyGoal ?? "Goal configured"
                )

                InfoCard(
                    icon: "moon.stars",
                    title: "Focus Time Ready",
                    description: "Peak productivity hours configured"
                )

                Text("Tap 'Start BeYou' to activate your digital wellness journey")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
            }
            .padding(.top, 20)
        }
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.black)
                .frame(width: 50, height: 50)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
}
