import Foundation
import FamilyControls

/// Manager for sharing data between main app and extensions using App Groups
class SharedDataManager {

    static let shared = SharedDataManager()

    private let appGroupIdentifier = "group.com.odudu.BeYou"

    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    // MARK: - App Intention

    func saveAppIntention(_ intention: AppIntention) {
        // Save legacy global values for backward compatibility
        sharedDefaults?.set(intention.timesPerDay, forKey: "intentionTimesPerDay")
        sharedDefaults?.set(intention.minutesPerSession, forKey: "intentionMinutesPerSession")

        // Save per-app intentions as JSON
        if let encoded = try? JSONEncoder().encode(intention.perAppIntentions) {
            sharedDefaults?.set(encoded, forKey: "perAppIntentions")
        }

        sharedDefaults?.synchronize()
    }

    func loadAppIntention() -> AppIntention {
        var intention = AppIntention()

        // Load legacy global values
        if let timesPerDay = sharedDefaults?.object(forKey: "intentionTimesPerDay") as? Int,
           timesPerDay > 0 {
            intention.timesPerDay = timesPerDay
        }

        if let minutesPerSession = sharedDefaults?.object(forKey: "intentionMinutesPerSession") as? Int,
           minutesPerSession > 0 {
            intention.minutesPerSession = minutesPerSession
        }

        // Load per-app intentions
        if let data = sharedDefaults?.data(forKey: "perAppIntentions"),
           let decoded = try? JSONDecoder().decode([String: IndividualAppIntention].self, from: data) {
            intention.perAppIntentions = decoded
        }

        return intention
    }

    // MARK: - Usage Stats

    func saveUsageStats(_ stats: AppUsageStats) {
        // Legacy global values
        sharedDefaults?.set(stats.breakthroughsToday, forKey: "breakthroughsToday")
        sharedDefaults?.set(stats.currentStreak, forKey: "currentStreak")
        sharedDefaults?.set(stats.longestStreak, forKey: "longestStreak")
        sharedDefaults?.set(stats.totalBreakthroughs, forKey: "totalBreakthroughs")
        sharedDefaults?.set(stats.lastResetDate, forKey: "lastResetDate")
        sharedDefaults?.set(stats.isUnlocked, forKey: "isUnlocked")
        sharedDefaults?.set(stats.unlockExpiryTime, forKey: "unlockExpiryTime")

        // Per-app data
        if let encoded = try? JSONEncoder().encode(stats.breakthroughsByApp) {
            sharedDefaults?.set(encoded, forKey: "breakthroughsByApp")
        }

        if let encoded = try? JSONEncoder().encode(stats.currentStreakByApp) {
            sharedDefaults?.set(encoded, forKey: "currentStreakByApp")
        }

        if let encoded = try? JSONEncoder().encode(stats.longestStreakByApp) {
            sharedDefaults?.set(encoded, forKey: "longestStreakByApp")
        }

        // Unlocked apps
        let unlockedArray = Array(stats.unlockedApps)
        if let encoded = try? JSONEncoder().encode(unlockedArray) {
            sharedDefaults?.set(encoded, forKey: "unlockedApps")
        }

        if let encoded = try? JSONEncoder().encode(stats.unlockExpiryByApp) {
            sharedDefaults?.set(encoded, forKey: "unlockExpiryByApp")
        }

        sharedDefaults?.synchronize()
    }

    func loadUsageStats() -> AppUsageStats {
        var stats = AppUsageStats()

        // Legacy global values
        stats.breakthroughsToday = sharedDefaults?.integer(forKey: "breakthroughsToday") ?? 0
        stats.currentStreak = sharedDefaults?.integer(forKey: "currentStreak") ?? 0
        stats.longestStreak = sharedDefaults?.integer(forKey: "longestStreak") ?? 0
        stats.totalBreakthroughs = sharedDefaults?.integer(forKey: "totalBreakthroughs") ?? 0

        if let lastResetDate = sharedDefaults?.object(forKey: "lastResetDate") as? Date {
            stats.lastResetDate = lastResetDate
        }

        stats.isUnlocked = sharedDefaults?.bool(forKey: "isUnlocked") ?? false

        if let unlockExpiryTime = sharedDefaults?.object(forKey: "unlockExpiryTime") as? Date {
            stats.unlockExpiryTime = unlockExpiryTime
        }

        // Per-app data
        if let data = sharedDefaults?.data(forKey: "breakthroughsByApp"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            stats.breakthroughsByApp = decoded
        }

        if let data = sharedDefaults?.data(forKey: "currentStreakByApp"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            stats.currentStreakByApp = decoded
        }

        if let data = sharedDefaults?.data(forKey: "longestStreakByApp"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            stats.longestStreakByApp = decoded
        }

        if let data = sharedDefaults?.data(forKey: "unlockedApps"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            stats.unlockedApps = Set(decoded)
        }

        if let data = sharedDefaults?.data(forKey: "unlockExpiryByApp"),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            stats.unlockExpiryByApp = decoded
        }

        return stats
    }

    // MARK: - Discipline Score

    func saveDisciplineScore(_ score: DisciplineScore) {
        sharedDefaults?.set(score.score, forKey: "disciplineScore")
        sharedDefaults?.set(score.nevermindCount, forKey: "nevermindCount")
        sharedDefaults?.set(score.breakthroughCount, forKey: "breakthroughCountTotal")
        sharedDefaults?.synchronize()
    }

    func loadDisciplineScore() -> DisciplineScore {
        var score = DisciplineScore()

        if let defaults = sharedDefaults, defaults.object(forKey: "disciplineScore") != nil {
            score.score = defaults.integer(forKey: "disciplineScore")
        } else {
            score.score = 100 // Default to 100 on first launch
        }
        score.nevermindCount = sharedDefaults?.integer(forKey: "nevermindCount") ?? 0
        score.breakthroughCount = sharedDefaults?.integer(forKey: "breakthroughCountTotal") ?? 0

        return score
    }

    // MARK: - Disconnect Schedule

    func saveDisconnectSchedule(_ schedule: DisconnectSchedule) {
        sharedDefaults?.set(schedule.type, forKey: "disconnectScheduleType")
        sharedDefaults?.set(schedule.startTime, forKey: "disconnectStartTime")
        sharedDefaults?.set(schedule.endTime, forKey: "disconnectEndTime")
        sharedDefaults?.synchronize()
    }

    func loadDisconnectSchedule() -> DisconnectSchedule {
        var schedule = DisconnectSchedule()

        schedule.type = sharedDefaults?.string(forKey: "disconnectScheduleType")

        if let startTime = sharedDefaults?.object(forKey: "disconnectStartTime") as? Date {
            schedule.startTime = startTime
        }

        if let endTime = sharedDefaults?.object(forKey: "disconnectEndTime") as? Date {
            schedule.endTime = endTime
        }

        return schedule
    }

    // MARK: - App Selection (Complex - needs encoding)

    func saveAppSelection(_ selection: FamilyActivitySelection) {
        // FamilyActivitySelection cannot be directly serialized
        // We need to encode the tokens

        // Save application tokens count (for now)
        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count

        sharedDefaults?.set(appCount, forKey: "selectedAppsCount")
        sharedDefaults?.set(categoryCount, forKey: "selectedCategoriesCount")

        // TODO: Properly encode application and category tokens
        // This is complex and requires NSSecureCoding
        sharedDefaults?.synchronize()
    }

    // MARK: - Pending App to Unlock

    func savePendingAppToUnlock(_ appName: String?) {
        print("💾 SHARED: Saving pending app: \(appName ?? "nil")")
        sharedDefaults?.set(appName, forKey: "pendingAppToUnlock")
        let success = sharedDefaults?.synchronize() ?? false
        print("💾 SHARED: Save synchronize result: \(success)")
    }

    func loadPendingAppToUnlock() -> String? {
        let appName = sharedDefaults?.string(forKey: "pendingAppToUnlock")
        print("💾 SHARED: Loading pending app: \(appName ?? "nil")")
        return appName
    }

    // MARK: - Intervention State

    func saveInterventionActive(_ isActive: Bool) {
        print("💾 SHARED: Saving intervention active: \(isActive)")
        sharedDefaults?.set(isActive, forKey: "isInterventionActive")
        let success = sharedDefaults?.synchronize() ?? false
        print("💾 SHARED: Save synchronize result: \(success)")
    }

    func loadInterventionActive() -> Bool {
        let isActive = sharedDefaults?.bool(forKey: "isInterventionActive") ?? false
        print("💾 SHARED: Loading intervention active: \(isActive)")
        return isActive
    }

    // MARK: - Schedule Shield Instructions State

    func saveScheduleShowInstructions(_ show: Bool) {
        sharedDefaults?.set(show, forKey: "scheduleShowInstructions")
        sharedDefaults?.synchronize()
    }

    func loadScheduleShowInstructions() -> Bool {
        return sharedDefaults?.bool(forKey: "scheduleShowInstructions") ?? false
    }

    // MARK: - Time Waster Apps (for Scheduled Blocking)

    func saveTimeWasterApps(_ apps: [String]) {
        print("💾 SHARED: Saving \(apps.count) time waster apps")
        if let encoded = try? JSONEncoder().encode(apps) {
            sharedDefaults?.set(encoded, forKey: "timeWasterApps")
        }
        sharedDefaults?.synchronize()
    }

    func loadTimeWasterApps() -> [String] {
        if let data = sharedDefaults?.data(forKey: "timeWasterApps"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            print("💾 SHARED: Loaded \(decoded.count) time waster apps")
            return decoded
        }
        print("💾 SHARED: No time waster apps found")
        return []
    }

    // MARK: - Block Type (Intention vs Schedule)

    /// Saves the type of block that's currently active
    /// - Parameter type: "intention" for app intention blocking, "schedule" for scheduled session blocking
    func saveBlockType(_ type: String) {
        print("💾 SHARED: Saving block type: \(type)")
        sharedDefaults?.set(type, forKey: "currentBlockType")
        sharedDefaults?.synchronize()
    }

    /// Loads the current block type
    /// - Returns: "intention" or "schedule", defaults to "intention" if not set
    func loadBlockType() -> String {
        let type = sharedDefaults?.string(forKey: "currentBlockType") ?? "intention"
        print("💾 SHARED: Loading block type: \(type)")
        return type
    }

    // MARK: - Device Token (for APNs)

    func saveDeviceToken(_ token: String) {
        print("💾 SHARED: Saving device token: \(token.prefix(20))...")
        sharedDefaults?.set(token, forKey: "apnsDeviceToken")
        sharedDefaults?.synchronize()
    }

    func loadDeviceToken() -> String? {
        let token = sharedDefaults?.string(forKey: "apnsDeviceToken")
        print("💾 SHARED: Loading device token: \(token?.prefix(20) ?? "nil")...")
        return token
    }

    // MARK: - User ID

    func saveUserID(_ userID: String) {
        print("💾 SHARED: Saving user ID: \(userID)")
        sharedDefaults?.set(userID, forKey: "userID")
        sharedDefaults?.synchronize()
    }

    func loadUserID() -> String? {
        return sharedDefaults?.string(forKey: "userID")
    }

    // MARK: - Onboarding Data

    func saveOnboardingData(_ data: OnboardingData) {
        if let encoded = try? JSONEncoder().encode(data) {
            sharedDefaults?.set(encoded, forKey: "onboardingData")
        }
        sharedDefaults?.synchronize()
    }

    func loadOnboardingData() -> OnboardingData? {
        guard let data = sharedDefaults?.data(forKey: "onboardingData"),
              let decoded = try? JSONDecoder().decode(OnboardingData.self, from: data) else {
            return nil
        }
        return decoded
    }

    // MARK: - Completion Flags

    func saveHasCompletedOnboarding(_ completed: Bool) {
        sharedDefaults?.set(completed, forKey: "hasCompletedOnboarding")
        sharedDefaults?.synchronize()
    }

    func loadHasCompletedOnboarding() -> Bool {
        return sharedDefaults?.bool(forKey: "hasCompletedOnboarding") ?? false
    }

    func saveHasCompletedSetup(_ completed: Bool) {
        sharedDefaults?.set(completed, forKey: "hasCompletedSetup")
        sharedDefaults?.synchronize()
    }

    func loadHasCompletedSetup() -> Bool {
        return sharedDefaults?.bool(forKey: "hasCompletedSetup") ?? false
    }

    // MARK: - App Display Name to Store Key Mapping

    func saveStoreKeyMapping(_ mapping: [String: String]) {
        print("💾 SHARED: Saving store key mapping: \(mapping)")
        if let encoded = try? JSONEncoder().encode(mapping) {
            sharedDefaults?.set(encoded, forKey: "storeKeyMapping")
        }
        sharedDefaults?.synchronize()
    }

    func loadStoreKeyMapping() -> [String: String] {
        if let data = sharedDefaults?.data(forKey: "storeKeyMapping"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            print("💾 SHARED: Loading store key mapping: \(decoded)")
            return decoded
        }
        print("💾 SHARED: No store key mapping found")
        return [:]
    }

    func updateStoreKeyMapping(displayName: String, storeKey: String) {
        var mapping = loadStoreKeyMapping()
        mapping[displayName] = storeKey
        saveStoreKeyMapping(mapping)
        print("💾 SHARED: Updated mapping: \(displayName) -> \(storeKey)")
    }

    // MARK: - Schedule-Specific Blocked Apps

    func saveScheduleBlockedApps(scheduleKey: String, blockedAppsData: Data) {
        print("💾 SHARED: Saving blocked apps for schedule: \(scheduleKey)")
        sharedDefaults?.set(blockedAppsData, forKey: "\(scheduleKey)_blockedApps")
        sharedDefaults?.synchronize()
    }

    func loadScheduleBlockedApps(scheduleKey: String) -> Data? {
        let data = sharedDefaults?.data(forKey: "\(scheduleKey)_blockedApps")
        print("💾 SHARED: Loading blocked apps for schedule: \(scheduleKey) - \(data != nil ? "Found" : "Not found")")
        return data
    }

    func removeScheduleBlockedApps(scheduleKey: String) {
        print("💾 SHARED: Removing blocked apps for schedule: \(scheduleKey)")
        sharedDefaults?.removeObject(forKey: "\(scheduleKey)_blockedApps")
        sharedDefaults?.synchronize()
    }

    // MARK: - Active Schedule Tracking

    func addActiveSchedule(_ scheduleKey: String) {
        var active = loadActiveScheduleKeys()
        active.insert(scheduleKey)
        if let encoded = try? JSONEncoder().encode(Array(active)) {
            sharedDefaults?.set(encoded, forKey: "activeScheduleKeys")
            sharedDefaults?.synchronize()
        }
        print("💾 SHARED: Added active schedule: \(scheduleKey), total: \(active.count)")
    }

    func removeActiveSchedule(_ scheduleKey: String) {
        var active = loadActiveScheduleKeys()
        active.remove(scheduleKey)
        if let encoded = try? JSONEncoder().encode(Array(active)) {
            sharedDefaults?.set(encoded, forKey: "activeScheduleKeys")
            sharedDefaults?.synchronize()
        }
        print("💾 SHARED: Removed active schedule: \(scheduleKey), total: \(active.count)")
    }

    func loadActiveScheduleKeys() -> Set<String> {
        if let data = sharedDefaults?.data(forKey: "activeScheduleKeys"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return Set(decoded)
        }
        return []
    }

    func isAnyScheduleActive() -> Bool {
        return !loadActiveScheduleKeys().isEmpty
    }

    // MARK: - Active Schedule Token Data (per-app checking)

    func loadActiveScheduleTokenData() -> [Data] {
        if let data = sharedDefaults?.data(forKey: "activeScheduleTokenData"),
           let decoded = try? JSONDecoder().decode([Data].self, from: data) {
            return decoded
        }
        return []
    }

    // MARK: - Pending Unlock Re-blocks
    // Stores data that DeviceActivityMonitorExtension needs to re-apply shields
    // after a temporary unlock expires. Keyed by "unlock_<storeKey>".

    /// Save a pending re-block so the monitor extension can re-apply the shield
    func savePendingReblock(storeKey: String, tokenData: Data) {
        var pending = loadAllPendingReblocks()
        pending[storeKey] = tokenData
        if let encoded = try? JSONEncoder().encode(pending) {
            sharedDefaults?.set(encoded, forKey: "pendingReblocks")
            sharedDefaults?.synchronize()
        }
        print("💾 SHARED: Saved pending reblock for \(storeKey)")
    }

    /// Remove a pending re-block after it's been applied
    func removePendingReblock(storeKey: String) {
        var pending = loadAllPendingReblocks()
        pending.removeValue(forKey: storeKey)
        if let encoded = try? JSONEncoder().encode(pending) {
            sharedDefaults?.set(encoded, forKey: "pendingReblocks")
            sharedDefaults?.synchronize()
        }
        print("💾 SHARED: Removed pending reblock for \(storeKey)")
    }

    /// Load all pending re-blocks
    func loadAllPendingReblocks() -> [String: Data] {
        if let data = sharedDefaults?.data(forKey: "pendingReblocks"),
           let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            return decoded
        }
        return [:]
    }

    func removeActiveScheduleTokensForSchedule(_ scheduleKey: String) {
        // Load this schedule's blocked apps to find which tokens to remove
        guard let blockedAppsData = loadScheduleBlockedApps(scheduleKey: scheduleKey) else {
            // No blocked apps data — clear all token data as fallback
            sharedDefaults?.removeObject(forKey: "activeScheduleTokenData")
            sharedDefaults?.synchronize()
            return
        }

        // Decode the FamilyActivitySelection to get the tokens
        // Note: FamilyActivitySelection is from FamilyControls which may not be available here
        // Instead, just clear all active tokens if no other schedules are active
        let remainingSchedules = loadActiveScheduleKeys()
        if remainingSchedules.isEmpty {
            // No more active schedules — clear all token data
            sharedDefaults?.removeObject(forKey: "activeScheduleTokenData")
            sharedDefaults?.synchronize()
            print("💾 SHARED: Cleared all active schedule token data (no schedules remaining)")
        }
    }

    // MARK: - Mood Tracking

    func saveMoodEntry(_ entry: MoodEntry) {
        var entries = loadMoodEntries()
        entries.append(entry)

        // Keep only last 30 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        entries = entries.filter { $0.date >= cutoff }

        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "moodEntries")
        }
    }

    func loadMoodEntries() -> [MoodEntry] {
        guard let data = UserDefaults.standard.data(forKey: "moodEntries"),
              let decoded = try? JSONDecoder().decode([MoodEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    /// Returns the average mood score (1-5) for each day in the past 7 days starting from the given week
    func moodAveragesForWeek(containing date: Date) -> [Double?] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1=Sun
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: date))!

        let entries = loadMoodEntries()
        var averages: [Double?] = Array(repeating: nil, count: 7)

        for i in 0..<7 {
            let day = calendar.date(byAdding: .day, value: i, to: startOfWeek)!
            let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
            if !dayEntries.isEmpty {
                let sum = dayEntries.reduce(0) { $0 + $1.score }
                averages[i] = Double(sum) / Double(dayEntries.count)
            }
        }

        return averages
    }
}

// MARK: - Mood Entry Model

struct MoodEntry: Codable {
    let score: Int // 1-5 (1=struggling, 5=great)
    let date: Date
    let appName: String?
}
