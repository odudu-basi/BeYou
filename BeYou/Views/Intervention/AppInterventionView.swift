import SwiftUI

struct AppInterventionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let appName: String
    let onNevermind: () -> Void
    let onOpenApp: () -> Void

    // Get app-specific stats from appState
    private var breakthroughCount: Int {
        appState.getAppBreakthroughs(appName)
    }

    private var dailyLimit: Int {
        appState.getAppLimit(appName)
    }

    private var streakDays: Int {
        appState.getAppStreak(appName)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // BeYou logo
                Image("be-you-icon")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(24)
                    .padding(.bottom, 40)

                // Title
                Text("Open the app?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 12)

                // Subtitle
                Text("Don't open this app more than \(dailyLimit) times today")
                    .font(.system(size: 17))
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)

                // Stats
                VStack(spacing: 12) {
                    // Opens today
                    Text("\(breakthroughCount)/\(dailyLimit) Opens Today")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)

                    // Streak
                    HStack(spacing: 6) {
                        Text("\(streakDays) Day Streak")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)

                        Text("🔥")
                            .font(.system(size: 24))
                    }
                }
                .padding(.bottom, 60)

                // Warning message (only show when at limit)
                if breakthroughCount >= dailyLimit {
                    VStack(spacing: 8) {
                        Text("You've reached your app intention,")
                            .font(.system(size: 16))
                            .foregroundColor(Color.white.opacity(0.9))

                        Text("You sure you want to open the app?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    // Primary button - Nevermind
                    Button(action: {
                        onNevermind()
                        dismiss()
                    }) {
                        Text(breakthroughCount >= dailyLimit ? "You're right, nevermind" : "Nevermind")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "5B9FFF"))
                            .cornerRadius(16)
                    }

                    // Secondary button - Open app
                    Button(action: {
                        onOpenApp()
                    }) {
                        Text(breakthroughCount >= dailyLimit ? "I'm begging you, open the app!" : "Open the app")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    let appState = AppState()
    appState.onboardingData.appIntention.perAppIntentions["Instagram"] = IndividualAppIntention(
        appName: "Instagram",
        timesPerDay: 10,
        minutesPerSession: 5
    )
    appState.appUsageStats.breakthroughsByApp["Instagram"] = 3
    appState.appUsageStats.currentStreakByApp["Instagram"] = 1

    return AppInterventionView(
        appName: "Instagram",
        onNevermind: {},
        onOpenApp: {}
    )
    .environmentObject(appState)
}
