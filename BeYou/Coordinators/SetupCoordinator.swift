import SwiftUI

enum SetupStep: Int, CaseIterable {
    case intro = 0
    case dailyGoal
    case appIntention
    case intentionComplete
    case scheduleInfo
    case complete

    var next: SetupStep? {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self),
              currentIndex + 1 < allCases.count else {
            return nil
        }
        return allCases[currentIndex + 1]
    }

    var previous: SetupStep? {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self),
              currentIndex > 0 else {
            return nil
        }
        return allCases[currentIndex - 1]
    }
}

@available(iOS 16.0, *)
struct SetupCoordinator: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var currentStep: SetupStep = .intro

    var body: some View {
        Group {
            switch currentStep {
            case .intro:
                SetupIntroView(onNext: advance)
            case .dailyGoal:
                SetupDailyGoalView(onNext: advance, onBack: goBack)
            case .appIntention:
                OnboardingPerAppIntentionView(currentStep: currentStep.rawValue + 1, totalSteps: SetupStep.allCases.count, onNext: {
                    // Apply shields and save data right after intentions are set
                    applyIntentions()
                    advance()
                }, onBack: goBack)
            case .intentionComplete:
                SetupIntentionCompleteView(onNext: advance, onBack: goBack)
            case .scheduleInfo:
                SetupScheduleInfoView(onNext: advance, onBack: goBack)
            case .complete:
                SetupCompleteView(onNext: finishSetup, onBack: goBack)
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    private func advance() {
        withAnimation {
            if let nextStep = currentStep.next {
                currentStep = nextStep
            } else {
                finishSetup()
            }
        }
    }

    private func goBack() {
        withAnimation {
            if let previousStep = currentStep.previous {
                currentStep = previousStep
            }
        }
    }

    private func applyIntentions() {
        // Per-app blocking is already applied by OnboardingPerAppIntentionView.saveIntention()
        // which calls screenTimeManager.blockApp(token:forKey:) for each app.
        // Do NOT call blockSelectedApps() here — it would also block the app in the
        // default (unnamed) store, causing the app to remain blocked even after
        // the intervention flow clears the named store.

        // Clear the default store to ensure no duplicate shields
        screenTimeManager.unblockAllApps()

        // Save app intention data and full onboarding data to shared storage
        SharedDataManager.shared.saveAppIntention(appState.onboardingData.appIntention)
        SharedDataManager.shared.saveOnboardingData(appState.onboardingData)
    }

    private func finishSetup() {
        // Per-app blocking is already handled by named stores.
        // Clear the default store to avoid duplicate blocks.
        screenTimeManager.unblockAllApps()

        SharedDataManager.shared.saveAppIntention(appState.onboardingData.appIntention)
        SharedDataManager.shared.saveOnboardingData(appState.onboardingData)
        SharedDataManager.shared.saveHasCompletedSetup(true)

        // Start every app with a streak of 1 on day one
        for appName in appState.onboardingData.appIntention.perAppIntentions.keys {
            appState.appUsageStats.currentStreakByApp[appName] = 1
            appState.appUsageStats.longestStreakByApp[appName] = 1
        }
        appState.appUsageStats.currentStreak = 1
        appState.appUsageStats.longestStreak = 1
        SharedDataManager.shared.saveUsageStats(appState.appUsageStats)

        // Navigate to main app
        appState.navigateTo(.main)
    }
}
