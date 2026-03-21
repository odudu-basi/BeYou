import SwiftUI

@available(iOS 16.0, *)
struct OnboardingNotificationPermissionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var isRequesting = false

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private var userName: String {
        appState.onboardingData.name ?? "there"
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Don't miss your\ndaily motivation")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .tracking(-0.3)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text("Get reminders and motivational messages\nto help you stay on track.")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "666666"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.top, 32)

                    // Phone mockup section
                    GeometryReader { geo in
                        let phoneWidth = geo.size.width * 0.6
                        let phoneHeight = phoneWidth * 2.05
                        let bannerWidth = geo.size.width * 0.92

                        ZStack(alignment: .top) {
                            // Phone body
                            VStack(spacing: 0) {
                                // Notch
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.black)
                                    .frame(width: 100, height: 28)
                                    .padding(.top, 16)

                                Spacer()
                            }
                            .frame(width: phoneWidth, height: phoneHeight)
                            .background(Color.black)
                            .cornerRadius(36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 36)
                                    .stroke(Color(hex: "2A2A2A"), lineWidth: 3)
                            )

                            // Notification banner - overlays the phone
                            HStack(spacing: 12) {
                                Image("be-you-icon")
                                    .resizable()
                                    .frame(width: 42, height: 42)
                                    .cornerRadius(10)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("Be You")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(hex: "1A1A1A"))

                                        Spacer()

                                        Text("now")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "999999"))
                                    }

                                    Text("\(userName), time for your mental health check before using this app.")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "666666"))
                                        .lineSpacing(4)
                                }
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .frame(width: bannerWidth)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 4)
                            .offset(y: 64)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }

                // Bottom buttons
                VStack(spacing: 12) {
                    Button(action: enableNotifications) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Enable Notifications")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "1A1A1A"))
                        .cornerRadius(16)
                    }
                    .disabled(isRequesting)

                    Button(action: onNext) {
                        Text("Maybe Later")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "999999"))
                    }
                    .disabled(isRequesting)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 12)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            // When user returns from Settings, check if they enabled notifications
            if newPhase == .active {
                Task {
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    if settings.authorizationStatus == .authorized {
                        await MainActor.run {
                            NotificationManager.shared.checkAuthorizationStatus()
                            scheduleAffirmationsIfNeeded()
                            onNext()
                        }
                    }
                }
            }
        }
    }

    private func enableNotifications() {
        isRequesting = true
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()

            await MainActor.run {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // Prompt hasn't been shown yet — show the system prompt
                    Task {
                        let granted = await NotificationManager.shared.requestAuthorization()
                        await MainActor.run {
                            isRequesting = false
                            if granted {
                                scheduleAffirmationsIfNeeded()
                            }
                            onNext()
                        }
                    }

                case .denied:
                    // User previously denied — open Settings so they can enable manually
                    isRequesting = false
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }

                case .authorized, .provisional, .ephemeral:
                    // Already authorized — just proceed
                    isRequesting = false
                    scheduleAffirmationsIfNeeded()
                    onNext()

                @unknown default:
                    isRequesting = false
                    onNext()
                }
            }
        }
    }

    private func scheduleAffirmationsIfNeeded() {
        if let count = appState.onboardingData.affirmationCount,
           let startTime = appState.onboardingData.notifyStartTime,
           let endTime = appState.onboardingData.notifyEndTime {
            NotificationManager.shared.scheduleAffirmationNotifications(
                count: count,
                startTime: startTime,
                endTime: endTime,
                categories: appState.onboardingData.categories,
                goals: appState.onboardingData.goals,
                belief: appState.onboardingData.religion ?? "general",
                name: appState.onboardingData.name ?? ""
            )
        }
    }
}
