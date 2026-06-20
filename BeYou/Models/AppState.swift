import SwiftUI
import Combine
import WidgetKit

enum AppScreen {
    case splash
    case welcome
    case onboarding
    case paywall
    case screenTimeConnect
    case setup
    case main
}

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var onboardingData = OnboardingData()
    @Published var appUsageStats = AppUsageStats()
    @Published var disciplineScore = DisciplineScore()
    @Published var challengeDisciplineBonus: Double = 0 { // +0.5 per completed challenge with discipline toggle
        didSet {
            recalculateDisciplineScore()
            // Save updated score to shared storage so widget picks it up
            sharedData.saveDisciplineScore(disciplineScore)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published var isInterventionActive = false
    @Published var pendingAppToUnlock: String? // Track which app is pending unlock

    private let sharedData = SharedDataManager.shared

    init() {
        // Load saved data on init
        loadPersistedData()

        // Always start at splash — SplashView determines where to go next
        currentScreen = .splash
    }

    func destinationAfterSplash() -> AppScreen {
        if sharedData.loadHasCompletedSetup() || !onboardingData.appIntention.perAppIntentions.isEmpty {
            if !sharedData.loadHasCompletedSetup() {
                sharedData.saveHasCompletedSetup(true)
            }
            return .main
        } else if sharedData.loadHasCompletedOnboarding() {
            return .screenTimeConnect
        }
        return .onboarding
    }

    func navigateTo(_ screen: AppScreen) {
        currentScreen = screen
    }

    private func loadPersistedData() {
        appUsageStats = sharedData.loadUsageStats()
        disciplineScore = sharedData.loadDisciplineScore()

        // Load full onboarding data if available, otherwise fall back to individual fields
        if let savedOnboarding = sharedData.loadOnboardingData() {
            onboardingData = savedOnboarding
        } else {
            onboardingData.appIntention = sharedData.loadAppIntention()
            onboardingData.disconnectSchedule = sharedData.loadDisconnectSchedule()
        }

        isInterventionActive = sharedData.loadInterventionActive()
        pendingAppToUnlock = sharedData.loadPendingAppToUnlock()

        // Migrate any token-based keys to display names on launch
        migrateTokenKeysToDisplayNames()
    }

    /// Reload shared data from App Groups to pick up any migrations done by the shield extension.
    /// This ensures in-memory state stays in sync with shield migrations (e.g., token key -> display name).
    func syncFromSharedStorage() {
        let freshIntention = sharedData.loadAppIntention()
        let freshStats = sharedData.loadUsageStats()

        // Merge migrated intention keys: if the shield migrated "app_123" -> "Instagram",
        // update our in-memory copy so saveAllData() doesn't overwrite the migration
        if Set(freshIntention.perAppIntentions.keys) != Set(onboardingData.appIntention.perAppIntentions.keys) {
            print("🔄 APP STATE: Shield migrated intention keys, syncing...")
            onboardingData.appIntention.perAppIntentions = freshIntention.perAppIntentions

            // Also update onboardingData in shared storage with migrated keys
            sharedData.saveOnboardingData(onboardingData)
        }

        // Sync breakthrough counts (shield may have migrated these too)
        appUsageStats.breakthroughsByApp = freshStats.breakthroughsByApp
        appUsageStats.currentStreakByApp = freshStats.currentStreakByApp
        appUsageStats.longestStreakByApp = freshStats.longestStreakByApp
        appUsageStats.unlockedApps = freshStats.unlockedApps
        appUsageStats.unlockExpiryByApp = freshStats.unlockExpiryByApp

        // Migrate any remaining token-keyed breakthrough data to display names
        migrateTokenKeysToDisplayNames()
    }

    /// Migrates any token-based keys (e.g. "app_123...") in breakthroughsByApp to display names
    /// using the storeKeyMapping. This cleans up data that was recorded before the shield migrated.
    private func migrateTokenKeysToDisplayNames() {
        let mapping = sharedData.loadStoreKeyMapping()
        guard !mapping.isEmpty else { return }

        // Build reverse map: tokenKey -> displayName
        var reverseMap: [String: String] = [:]
        for (displayName, tokenKey) in mapping {
            reverseMap[tokenKey] = displayName
        }

        var didMigrate = false

        // Migrate breakthroughsByApp
        for (key, value) in appUsageStats.breakthroughsByApp where key.hasPrefix("app_") {
            if let displayName = reverseMap[key] {
                appUsageStats.breakthroughsByApp[displayName, default: 0] += value
                appUsageStats.breakthroughsByApp.removeValue(forKey: key)
                didMigrate = true
            }
        }

        // Migrate currentStreakByApp
        for (key, value) in appUsageStats.currentStreakByApp where key.hasPrefix("app_") {
            if let displayName = reverseMap[key] {
                appUsageStats.currentStreakByApp[displayName] = value
                appUsageStats.currentStreakByApp.removeValue(forKey: key)
                didMigrate = true
            }
        }

        // Migrate longestStreakByApp
        for (key, value) in appUsageStats.longestStreakByApp where key.hasPrefix("app_") {
            if let displayName = reverseMap[key] {
                appUsageStats.longestStreakByApp[displayName] = value
                appUsageStats.longestStreakByApp.removeValue(forKey: key)
                didMigrate = true
            }
        }

        if didMigrate {
            print("🔄 APP STATE: Migrated token keys to display names in stats")
            sharedData.saveUsageStats(appUsageStats)
        }
    }

    private func saveAllData() {
        sharedData.saveUsageStats(appUsageStats)
        sharedData.saveDisciplineScore(disciplineScore)
        sharedData.saveAppIntention(onboardingData.appIntention)
        sharedData.saveDisconnectSchedule(onboardingData.disconnectSchedule)
        sharedData.saveTimeWasterApps(onboardingData.timeWasterApps)
        sharedData.saveOnboardingData(onboardingData)

        // NOTE: Do NOT save isInterventionActive and pendingAppToUnlock here!
        // These are managed by Shield extensions and should only be saved explicitly
        // when changed, otherwise we overwrite the extension's values with stale data.
        // sharedData.saveInterventionActive(isInterventionActive)
        // sharedData.savePendingAppToUnlock(pendingAppToUnlock)

        // Refresh widgets with latest data
        WidgetCenter.shared.reloadAllTimelines()
    }

    func checkDailyReset() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(appUsageStats.lastResetDate) {
            // Save yesterday's snapshot before resetting
            WeeklyHistoryManager.shared.saveToday(
                score: disciplineScore.score,
                breakthroughsByApp: appUsageStats.breakthroughsByApp,
                total: appUsageStats.breakthroughsToday
            )

            // New day - check per-app streaks (loop over all active intentions, not just apps with breakthroughs)
            for (appName, appIntention) in onboardingData.appIntention.perAppIntentions {
                let yesterdayBreakthroughs = appUsageStats.breakthroughsByApp[appName] ?? 0
                let limit = appIntention.timesPerDay

                if yesterdayBreakthroughs <= limit {
                    let currentStreak = (appUsageStats.currentStreakByApp[appName] ?? 0) + 1
                    appUsageStats.currentStreakByApp[appName] = currentStreak

                    if currentStreak > (appUsageStats.longestStreakByApp[appName] ?? 0) {
                        appUsageStats.longestStreakByApp[appName] = currentStreak
                    }
                } else {
                    appUsageStats.currentStreakByApp[appName] = 0
                }
            }

            // Overall streak: maintained as long as the user has at least one active intention
            let hasActiveIntention = !onboardingData.appIntention.perAppIntentions.isEmpty
            if hasActiveIntention {
                appUsageStats.currentStreak += 1
                if appUsageStats.currentStreak > appUsageStats.longestStreak {
                    appUsageStats.longestStreak = appUsageStats.currentStreak
                }
            } else {
                appUsageStats.currentStreak = 0
            }

            // Schedule streak notification
            if #available(iOS 16.0, *) {
                NotificationManager.shared.scheduleStreakNotification(
                    streakDays: appUsageStats.currentStreak,
                    didMaintainStreak: hasActiveIntention
                )
            }

            // Reset daily counters
            disciplineScore.score = 100 // Fresh start every day
            disciplineScore.nevermindCount = 0
            challengeDisciplineBonus = 0
            appUsageStats.breakthroughsToday = 0
            appUsageStats.breakthroughsByApp.removeAll()
            appUsageStats.lastResetDate = Date()
            appUsageStats.isUnlocked = false
            appUsageStats.unlockedApps.removeAll()
            appUsageStats.unlockExpiryTime = nil
            appUsageStats.unlockExpiryByApp.removeAll()
            appUsageStats.affirmationsViewed = 0

            // Schedule streak warning if user has no intentions (streak at risk)
            if #available(iOS 16.0, *) {
                if onboardingData.appIntention.perAppIntentions.isEmpty && appUsageStats.currentStreak > 0 {
                    NotificationManager.shared.scheduleStreakWarningNotification(currentStreak: appUsageStats.currentStreak)
                } else {
                    NotificationManager.shared.cancelStreakWarningNotification()
                }
            }

            // Save to shared storage
            saveAllData()
        }
    }

    func recordNevermind() {
        disciplineScore.nevermindCount += 1

        // Track nevermind
        AnalyticsManager.shared.trackNevermindRecorded()

        // Reward self-control: +0.5 per nevermind
        recalculateDisciplineScore()
        saveAllData()
    }

    /// Translates a token-based key (e.g. "app_123...") to a display name.
    /// Checks storeKeyMapping first, then falls back to finding a migrated key in perAppIntentions.
    private func resolveDisplayName(_ key: String) -> String {
        guard key.hasPrefix("app_") else { return key }

        // Strategy 1: Check storeKeyMapping (populated by shield migration)
        let mapping = sharedData.loadStoreKeyMapping()
        for (displayName, tokenKey) in mapping {
            if tokenKey == key { return displayName }
        }

        // Strategy 2: Check if a non-token key exists in perAppIntentions with the same token data
        // This handles the case where the shield already migrated the key but the mapping wasn't saved
        if let tokenIntention = onboardingData.appIntention.perAppIntentions[key],
           let tokenData = tokenIntention.appTokenData {
            for (otherKey, otherIntention) in onboardingData.appIntention.perAppIntentions {
                if !otherKey.hasPrefix("app_"),
                   let otherData = otherIntention.appTokenData,
                   otherData == tokenData {
                    return otherKey
                }
            }
        }

        // Strategy 3: If there's only one intention and it has a display name, use it
        let nonTokenKeys = onboardingData.appIntention.perAppIntentions.keys.filter { !$0.hasPrefix("app_") }
        if onboardingData.appIntention.perAppIntentions.count == 1, let singleKey = nonTokenKeys.first {
            return singleKey
        }

        return key
    }

    func recordBreakthrough(for appName: String? = nil) {
        let oldScore = disciplineScore.score
        let rawApp = appName ?? pendingAppToUnlock ?? "Unknown App"
        let targetApp = resolveDisplayName(rawApp)

        // Update per-app breakthrough count
        let currentAppBreakthroughs = appUsageStats.breakthroughsByApp[targetApp] ?? 0
        appUsageStats.breakthroughsByApp[targetApp] = currentAppBreakthroughs + 1

        // Update overall counters
        appUsageStats.breakthroughsToday += 1
        appUsageStats.totalBreakthroughs += 1
        disciplineScore.breakthroughCount += 1

        // Recalculate discipline score using new formula
        recalculateDisciplineScore()

        // Schedule app limit warning notification if approaching limit
        if #available(iOS 16.0, *) {
            let appIntention = onboardingData.appIntention.perAppIntentions[targetApp]
            let limit = appIntention?.timesPerDay ?? onboardingData.appIntention.timesPerDay
            let appBreakthroughs = appUsageStats.breakthroughsByApp[targetApp] ?? 0

            NotificationManager.shared.scheduleAppLimitWarning(
                currentOpens: appBreakthroughs,
                limit: limit,
                appName: targetApp
            )

            // Show discipline score change (only if significant)
            if oldScore != disciplineScore.score {
                NotificationManager.shared.showDisciplineScoreUpdate(
                    score: disciplineScore.score,
                    change: disciplineScore.score - oldScore
                )
                AnalyticsManager.shared.trackDisciplineScoreChanged(oldScore: oldScore, newScore: disciplineScore.score)
            }
        }

        // Track breakthrough
        AnalyticsManager.shared.trackBreakthroughRecorded(appName: targetApp, totalToday: appUsageStats.breakthroughsToday)

        saveAllData()
    }

    func unlockApp(appName: String? = nil) {
        let rawApp = appName ?? pendingAppToUnlock ?? "Unknown App"
        let targetApp = resolveDisplayName(rawApp)

        // Get app-specific session duration
        let appIntention = onboardingData.appIntention.perAppIntentions[targetApp]
        let sessionMinutes = appIntention?.minutesPerSession ?? onboardingData.appIntention.minutesPerSession
        let sessionDuration = TimeInterval(sessionMinutes * 60)
        let expiryTime = Date().addingTimeInterval(sessionDuration)

        // Track per-app unlock
        appUsageStats.unlockedApps.insert(targetApp)
        appUsageStats.unlockExpiryByApp[targetApp] = expiryTime

        // Legacy support
        appUsageStats.isUnlocked = true
        appUsageStats.unlockExpiryTime = expiryTime
        appUsageStats.affirmationsViewed = 0 // Reset for next time

        saveAllData()
    }

    func checkIfUnlockExpired(for appName: String? = nil) -> Bool {
        if let targetApp = appName {
            // Check specific app
            guard let expiryTime = appUsageStats.unlockExpiryByApp[targetApp] else { return true }
            if Date() > expiryTime {
                appUsageStats.unlockedApps.remove(targetApp)
                appUsageStats.unlockExpiryByApp.removeValue(forKey: targetApp)
                saveAllData()
                return true
            }
            return false
        } else {
            // Legacy: Check global unlock
            guard let expiryTime = appUsageStats.unlockExpiryTime else { return true }
            if Date() > expiryTime {
                appUsageStats.isUnlocked = false
                appUsageStats.unlockExpiryTime = nil
                appUsageStats.unlockedApps.removeAll()
                appUsageStats.unlockExpiryByApp.removeAll()
                saveAllData()
                return true
            }
            return false
        }
    }

    func isAppUnlocked(_ appName: String) -> Bool {
        // Check if app is currently unlocked and not expired
        guard appUsageStats.unlockedApps.contains(appName) else { return false }
        return !checkIfUnlockExpired(for: appName)
    }

    func getAppBreakthroughs(_ appName: String) -> Int {
        return appUsageStats.breakthroughsByApp[appName] ?? 0
    }

    func getAppLimit(_ appName: String) -> Int {
        return onboardingData.appIntention.perAppIntentions[appName]?.timesPerDay ?? onboardingData.appIntention.timesPerDay
    }

    func getAppStreak(_ appName: String) -> Int {
        return appUsageStats.currentStreakByApp[appName] ?? 0
    }

    /// Recalculates discipline score based on total extra opens across all blocked apps.
    /// Score starts at 100. Only deducted when user goes OVER their per-app limits.
    /// Floor is 40 — even on the worst day, score never drops below 40.
    private func recalculateDisciplineScore() {
        // Every open past the app's limit deducts 2 points
        var totalExtraOpens = 0
        for (appName, breakthroughs) in appUsageStats.breakthroughsByApp {
            let limit = getAppLimit(appName)
            totalExtraOpens += max(0, breakthroughs - limit)
        }

        let deduction = totalExtraOpens * 2
        let nevermindBonus = disciplineScore.nevermindCount

        // Challenge bonus: +0.5 per completed challenge with discipline toggle
        // Only whole points count (e.g. 2 challenges = +1, 3 challenges = +1)
        let challengeBonus = Int(challengeDisciplineBonus)

        let finalScore = 100 - deduction + nevermindBonus + challengeBonus
        disciplineScore.score = max(0, min(100, finalScore))
    }
}

struct AppIntention: Codable {
    var timesPerDay: Int = 10 // Deprecated - kept for backward compatibility
    var minutesPerSession: Int = 5 // Deprecated - kept for backward compatibility
    var perAppIntentions: [String: IndividualAppIntention] = [:] // New: per-app settings
}

struct IndividualAppIntention: Codable {
    var appName: String
    var bundleIdentifier: String?
    var appTokenData: Data? // Stores encoded ApplicationToken for icon display
    var timesPerDay: Int
    var minutesPerSession: Int

    init(appName: String, bundleIdentifier: String? = nil, appTokenData: Data? = nil, timesPerDay: Int = 10, minutesPerSession: Int = 5) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.appTokenData = appTokenData
        self.timesPerDay = timesPerDay
        self.minutesPerSession = minutesPerSession
    }
}

struct DisconnectSchedule: Codable {
    var type: String? // "morning", "beforeBed", "atWork"
    var startTime: Date?
    var endTime: Date?
}

struct AppUsageStats {
    var breakthroughsToday: Int = 0 // Deprecated - total across all apps
    var breakthroughsByApp: [String: Int] = [:] // New: per-app breakthrough tracking
    var lastResetDate: Date = Date()
    var currentStreakByApp: [String: Int] = [:] // New: per-app streaks
    var longestStreakByApp: [String: Int] = [:] // New: per-app longest streaks
    var currentStreak: Int = 0 // Deprecated - overall streak
    var longestStreak: Int = 0 // Deprecated - overall longest streak
    var totalBreakthroughs: Int = 0
    var affirmationsViewed: Int = 0 // Tracks affirmations viewed during current intervention
    var isUnlocked: Bool = false
    var unlockedApps: Set<String> = [] // New: track which apps are currently unlocked
    var unlockExpiryTime: Date? // Deprecated - now per app
    var unlockExpiryByApp: [String: Date] = [:] // New: per-app expiry times
}

struct DisciplineScore {
    var score: Int = 100 // Starts at 100 each day, only deducted for going over limits
    var nevermindCount: Int = 0
    var breakthroughCount: Int = 0
}

struct OnboardingData: Codable {
    var referral: String?
    var name: String?
    var gender: String?
    var goals: [String] = []
    var currentScreenTime: Int?
    var goalTime: Int?
    var appIntention: AppIntention = AppIntention()
    var disconnectSchedule: DisconnectSchedule = DisconnectSchedule()
    var timeWasterApps: [String] = []
    var selectedAppsForBlocking: [String] = [] // New: list of app names user wants to block
    var hardToQuitReasons: [String] = []
    var feelings: [String] = []
    var age: Int?
    var triedBefore: [String] = []
    var relationship: String?
    var religion: String?
    var beliefs: [String] = []
    var affirmationFamiliarity: String?
    var affirmationCount: Int?
    var notifyStartTime: Date?
    var notifyEndTime: Date?
    var currentMood: String?
    var improveMethods: [String] = []
    var clearVision: String?
    var believeManifestation: String?
    var thoughtsShapeReality: String?
    var categories: [String] = []
    var iconStyle: String?
    var blockedAppTokens: [String] = []
    var dailyGoal: String?
    var allowedApps: [String] = []

    // Onboarding 2 fields
    var morningPerson: String?
    var referralSource: String?
    var biggestObstacle: String?
    var alarmCount: String?
    var trustFirstAlarm: String?
    var turnOffAlarm: String?
    var alarmThought: String?
    var negotiateStayInBed: String?
    var usualWakeTime: String?
    var idealWakeTime: String?
    var feelAfterWaking: String?
    var timeToFeelAwake: String?
    var clearBrainFog: String?
}
