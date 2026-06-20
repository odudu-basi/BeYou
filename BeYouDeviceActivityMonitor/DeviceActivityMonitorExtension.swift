//
//  DeviceActivityMonitorExtension.swift
//  BeYouDeviceActivityMonitor
//
//  Created by Oduduabasi Victor on 3/8/26.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    let store = ManagedSettingsStore()
    let sharedData = SharedDataManager.shared

    // Named stores for schedule-specific blocking
    var scheduleStores: [String: ManagedSettingsStore] = [:]

    // MARK: - Interval Callbacks (Disconnect Schedules)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Extract the actual schedule key from DeviceActivityName
        let activityString = "\(activity)"
        let scheduleKey = extractScheduleKey(from: activityString)

        // Skip unlock re-block activities
        if scheduleKey.hasPrefix("unlock_") {
            print("🔔 MONITOR: Ignoring intervalDidStart for unlock activity: \(scheduleKey)")
            return
        }

        // Handle meditation schedule activation
        if scheduleKey.hasPrefix("meditation_") {
            print("🧘 MONITOR: Meditation schedule started: \(scheduleKey)")
            activateMeditationBlock(scheduleKey: scheduleKey)
            return
        }

        let activityName = getActivityDisplayName(activity)

        print("🔔 MONITOR: ========================================")
        print("🔔 MONITOR: Schedule started!")
        print("🔔 MONITOR: Activity raw: \(activity)")
        print("🔔 MONITOR: Activity string: \(activityString)")
        print("🔔 MONITOR: Extracted key: \(scheduleKey)")
        print("🔔 MONITOR: Display name: \(activityName)")
        print("🔔 MONITOR: ========================================")

        // Mark this schedule as active in App Groups
        sharedData.addActiveSchedule(scheduleKey)

        // Apply shields for this specific schedule
        applyScheduleShields(for: scheduleKey)

        // Send notification
        sendNotification(
            title: "\(activityName) Started",
            body: "Your disconnect time is now active. Focus on what matters! 🧘",
            identifier: "disconnect_started_\(activityName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        )
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        let activityString = "\(activity)"
        let scheduleKey = extractScheduleKey(from: activityString)

        if scheduleKey.hasPrefix("unlock_") {
            print("🔔 MONITOR: Ignoring intervalDidEnd for unlock activity: \(scheduleKey)")
            return
        }

        // Meditation schedules don't have an end — they stay until completed
        if scheduleKey.hasPrefix("meditation_") {
            print("🧘 MONITOR: Ignoring intervalDidEnd for meditation: \(scheduleKey)")
            return
        }

        // Disconnect time ended - remove schedule-specific shields
        let activityName = getActivityDisplayName(activity)

        print("🔔 MONITOR: Schedule ended - \(scheduleKey)")

        // Mark this schedule as no longer active
        sharedData.removeActiveSchedule(scheduleKey)

        // Remove shields for this specific schedule
        removeScheduleShields(for: scheduleKey)

        // Send notification
        sendNotification(
            title: "\(activityName) Ended",
            body: "Your disconnect time is complete. Great job staying focused! ✨",
            identifier: "disconnect_ended_\(activityName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        )
    }

    // MARK: - Unlock Re-block

    /// Re-applies the shield for an app whose temporary unlock has expired.
    /// Called by iOS even if the main app is killed.
    private func handleUnlockReblock(storeKey: String) {
        print("🔔 MONITOR: Unlock expired for \(storeKey) — re-applying shield")

        // Load the pending re-block data (token data saved by main app)
        let pending = sharedData.loadAllPendingReblocks()
        guard let tokenData = pending[storeKey] else {
            print("❌ MONITOR: No pending reblock data for \(storeKey) — intention was likely deleted")
            return
        }

        // Safety: verify the intention still exists before re-blocking
        // If user deleted the intention, we should NOT re-block
        let intention = sharedData.loadAppIntention()
        // Load store key mapping from shared defaults (display name -> token key)
        let defaults = UserDefaults(suiteName: "group.com.odudu.BeYou")
        let storeKeyMapping: [String: String] = {
            if let data = defaults?.data(forKey: "storeKeyMapping"),
               let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                return decoded
            }
            return [:]
        }()
        let intentionExists = intention.perAppIntentions.contains { key, _ in
            let resolvedKey = storeKeyMapping[key] ?? key
            return resolvedKey == storeKey || key == storeKey
        }
        if !intentionExists {
            print("❌ MONITOR: Intention no longer exists for \(storeKey) — skipping re-block")
            sharedData.removePendingReblock(storeKey: storeKey)
            return
        }

        // Decode the token
        guard let token = try? JSONDecoder().decode(ApplicationToken.self, from: tokenData) else {
            print("❌ MONITOR: Failed to decode token for \(storeKey)")
            return
        }

        // Re-apply the shield using a named store
        let namedStore = ManagedSettingsStore(named: ManagedSettingsStore.Name(storeKey))
        namedStore.shield.applications = [token]
        print("✅ MONITOR: Shield re-applied for \(storeKey)")

        // Clean up pending reblock
        sharedData.removePendingReblock(storeKey: storeKey)

        // Clear unlock state in shared storage
        sharedData.clearUnlockState(storeKey: storeKey)

        // Send notification
        sendNotification(
            title: "Session Ended",
            body: "Your unlock session has ended. Stay mindful! 🧘",
            identifier: "unlock_ended_\(storeKey)"
        )
    }

    // MARK: - Event Callbacks (Daily Limits & Unlock Re-blocks)

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        let eventString = "\(event)"
        let activityString = "\(activity)"
        let activityKey = extractScheduleKey(from: activityString)

        print("🔔 MONITOR: Event threshold reached!")
        print("🔔 MONITOR: Event: \(eventString), Activity: \(activityKey)")

        // Check if this is an unlock warning event (1 minute remaining)
        if eventString.hasPrefix("unlock_warning_") {
            let storeKey = String(eventString.dropFirst("unlock_warning_".count))
            print("🔔 MONITOR: 1 minute remaining for unlocked app \(storeKey)")
            sendNotification(
                title: "1 Minute Left",
                body: "Your unlock session is almost over. Wrap up what you're doing!",
                identifier: "unlock_warning_\(storeKey)"
            )
            return
        }

        // Check if this is an unlock re-block event
        if activityKey.hasPrefix("unlock_") {
            let storeKey = String(activityKey.dropFirst("unlock_".count))
            print("🔔 MONITOR: Usage limit reached for unlocked app \(storeKey) — re-blocking")
            handleUnlockReblock(storeKey: storeKey)
            return
        }

        // Otherwise, it's a daily limit event
        applyShieldsFromSharedData()

        sendNotification(
            title: "Daily Limit Reached",
            body: "You've reached your limit for today. Great work building discipline! 💪",
            identifier: "daily_limit_reached_\(Date().timeIntervalSince1970)"
        )
    }

    // MARK: - Warning Callbacks

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)

        // Warning before disconnect time starts (typically 5-10 minutes before)
        let activityName = getActivityDisplayName(activity)

        sendNotification(
            title: "\(activityName) Starting Soon",
            body: "Your disconnect time starts in 5 minutes. Wrap up what you're doing.",
            identifier: "disconnect_warning_\(activityName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        )
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)

        // Warning before disconnect time ends
        let activityName = getActivityDisplayName(activity)

        sendNotification(
            title: "\(activityName) Ending Soon",
            body: "Your disconnect time ends in 5 minutes. Keep up the great work!",
            identifier: "disconnect_end_warning_\(activityName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        )
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)

        // Warning before user hits their daily limit
        sendNotification(
            title: "Approaching Your Limit",
            body: "You're getting close to your daily goal. Stay mindful! 🎯",
            identifier: "limit_warning_\(Date().timeIntervalSince1970)"
        )
    }

    // MARK: - Meditation Blocking

    private let meditationStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("meditation"))

    private func activateMeditationBlock(scheduleKey: String) {
        // Extract the meditation time from the schedule key
        let meditationTimes = sharedData.loadMeditationTimes()
        var matchedTime: MeditationTime?

        for time in meditationTimes {
            let prefix = "meditation_\(time.id.uuidString)"
            if scheduleKey.hasPrefix(prefix) {
                matchedTime = time
                break
            }
        }

        guard let time = matchedTime else {
            print("🧘 MONITOR: Could not find meditation time for schedule: \(scheduleKey)")
            return
        }

        let timeKey = String(format: "%02d:%02d", time.hour, time.minute)

        // Check if current time is actually close to the scheduled time (within 5 minutes)
        // This prevents false triggers when a schedule is registered mid-day
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTotal = currentHour * 60 + currentMinute
        let scheduledTotal = time.hour * 60 + time.minute
        let diff = abs(currentTotal - scheduledTotal)
        let wrappedDiff = min(diff, 1440 - diff)

        if wrappedDiff > 3 {
            print("🧘 MONITOR: Current time is \(wrappedDiff) min from scheduled \(timeKey) — false trigger, skipping")
            return
        }

        // Check if this time slot was already completed today
        if sharedData.loadMeditationCompletedForTime(timeKey) {
            print("🧘 MONITOR: Meditation \(timeKey) already completed today — skipping block")
            return
        }

        // Load meditation app selection from shared storage
        guard let selectionData = sharedData.loadMeditationAppSelection(),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) else {
            print("🧘 MONITOR: No meditation app selection found")
            return
        }

        if !selection.applicationTokens.isEmpty {
            meditationStore.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            meditationStore.shield.applicationCategories = .specific(selection.categoryTokens)
        }

        // Save active time key so the intervention knows which slot to mark complete
        sharedData.saveActiveMeditationTimeKey(timeKey)

        // Mark meditation block as active
        sharedData.saveMeditationBlockActive(true)

        print("🧘 MONITOR: Meditation block activated — \(selection.applicationTokens.count) apps blocked")
    }

    // MARK: - Helper Methods

    /// Extract the schedule key from DeviceActivityName string
    /// Input: "DeviceActivityName(rawValue: "schedule_UUID")" or "schedule_UUID"
    /// Output: "schedule_UUID"
    private func extractScheduleKey(from activityString: String) -> String {
        // Check if it's in the format: DeviceActivityName(rawValue: "...")
        if activityString.contains("rawValue:") {
            // Extract the value between quotes
            if let startRange = activityString.range(of: "\""),
               let endRange = activityString.range(of: "\"", options: .backwards),
               startRange != endRange {
                let key = String(activityString[startRange.upperBound..<endRange.lowerBound])
                return key
            }
        }

        // Otherwise, return as-is (for legacy schedule names like "morningSchedule")
        return activityString
    }

    private func applyScheduleShields(for activityString: String) {
        print("🔒 MONITOR: ========================================")
        print("🔒 MONITOR: Attempting to apply shields")
        print("🔒 MONITOR: Looking for key: \(activityString)")
        print("🔒 MONITOR: ========================================")

        // Load blocked apps for this specific schedule
        guard let blockedAppsData = sharedData.loadScheduleBlockedApps(scheduleKey: activityString) else {
            print("❌ MONITOR: ========================================")
            print("❌ MONITOR: No blocked apps data found!")
            print("❌ MONITOR: Tried key: \(activityString)_blockedApps")
            print("❌ MONITOR: This means the schedule has no apps selected")
            print("❌ MONITOR: OR there's a key mismatch")
            print("❌ MONITOR: Falling back to legacy global blocking")
            print("❌ MONITOR: ========================================")
            applyShieldsFromSharedData()
            return
        }

        print("✅ MONITOR: Found blocked apps data (\(blockedAppsData.count) bytes)")

        // Decode the FamilyActivitySelection
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: blockedAppsData) else {
            print("❌ MONITOR: ========================================")
            print("❌ MONITOR: Failed to decode FamilyActivitySelection")
            print("❌ MONITOR: Data size: \(blockedAppsData.count) bytes")
            print("❌ MONITOR: This is a critical error!")
            print("❌ MONITOR: ========================================")
            return
        }

        print("✅ MONITOR: Successfully decoded FamilyActivitySelection")
        print("✅ MONITOR: Application tokens: \(selection.applicationTokens.count)")
        print("✅ MONITOR: Category tokens: \(selection.categoryTokens.count)")

        // Save each blocked app's encoded token data so shield extensions can check per-app
        var tokenDataArray: [Data] = []
        for token in selection.applicationTokens {
            if let encoded = try? JSONEncoder().encode(token) {
                tokenDataArray.append(encoded)
            }
        }
        sharedData.addActiveScheduleTokens(tokenDataArray)
        print("✅ MONITOR: Saved \(tokenDataArray.count) active schedule token data entries")

        // Get or create a named store for this schedule
        let scheduleStore = getOrCreateScheduleStore(for: activityString)

        // Apply shields to the schedule-specific apps
        scheduleStore.shield.applications = selection.applicationTokens
        scheduleStore.shield.applicationCategories = .specific(selection.categoryTokens)

        print("✅ MONITOR: ========================================")
        print("✅ MONITOR: Shields applied successfully!")
        print("✅ MONITOR: Store name: \(activityString)")
        print("✅ MONITOR: Apps blocked: \(selection.applicationTokens.count)")
        print("✅ MONITOR: ========================================")
    }

    private func removeScheduleShields(for activityString: String) {
        print("🔓 MONITOR: Removing shields for schedule: \(activityString)")

        // Remove this schedule's token data from the active set
        if let blockedAppsData = sharedData.loadScheduleBlockedApps(scheduleKey: activityString),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: blockedAppsData) {
            var tokenDataToRemove: [Data] = []
            for token in selection.applicationTokens {
                if let encoded = try? JSONEncoder().encode(token) {
                    tokenDataToRemove.append(encoded)
                }
            }
            sharedData.removeActiveScheduleTokens(tokenDataToRemove)
            print("🔓 MONITOR: Removed \(tokenDataToRemove.count) token data entries for schedule: \(activityString)")
        }

        // Always clear schedule shields — daily limit exceeded is irrelevant for schedules.
        // Create a fresh store (don't rely on in-memory dictionary which may be lost on restart).
        let scheduleStore = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: activityString))
        scheduleStore.clearAllSettings()
        scheduleStores.removeValue(forKey: activityString)
        print("✅ MONITOR: Cleared all settings for schedule store: \(activityString)")
    }

    private func getOrCreateScheduleStore(for scheduleKey: String) -> ManagedSettingsStore {
        if let existingStore = scheduleStores[scheduleKey] {
            return existingStore
        }

        // Create new named store for this schedule
        let newStore = ManagedSettingsStore(named: ManagedSettingsStore.Name(scheduleKey))
        scheduleStores[scheduleKey] = newStore
        print("📦 MONITOR: Created new store for schedule: \(scheduleKey)")
        return newStore
    }

    private func applyShieldsFromSharedData() {
        // Legacy method for backward compatibility
        // Load app intentions to know which apps to block
        let intention = sharedData.loadAppIntention()

        // Note: We can't directly access the FamilyActivitySelection tokens here
        // The main app should have already set up the shields via ManagedSettingsStore
        // This method is kept for potential future token-based blocking

        // For now, we rely on the main app's ScreenTimeManager.blockSelectedApps()
        // which sets store.shield.applications and store.shield.applicationCategories

        // If needed, we can apply additional restrictions here
        // For example, blocking all apps during disconnect times
    }

    private func removeAllShields() {
        // Only remove shields if no apps have exceeded their daily limits
        // This is checked before calling this method
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    private func anyAppsExceededLimit() -> Bool {
        let stats = sharedData.loadUsageStats()
        let intention = sharedData.loadAppIntention()

        // Check if any app has exceeded its limit
        for (appName, breakthroughs) in stats.breakthroughsByApp {
            let appIntention = intention.perAppIntentions[appName]
            let limit = appIntention?.timesPerDay ?? intention.timesPerDay

            if breakthroughs >= limit {
                return true
            }
        }

        return false
    }

    private func getActivityDisplayName(_ activity: DeviceActivityName) -> String {
        let activityString = "\(activity)"

        if activityString.contains("morning") {
            return "Morning Focus"
        } else if activityString.contains("beforeBed") || activityString.contains("bed") {
            return "Before Bed"
        } else if activityString.contains("work") {
            return "Work Focus"
        } else if activityString.contains("daily") {
            return "Daily Intention"
        }

        return "Disconnect Time"
    }

    private func sendNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
}

// MARK: - SharedDataManager (Extension Version)
// Copy of SharedDataManager for use in the extension

class SharedDataManager {
    static let shared = SharedDataManager()
    private let appGroupIdentifier = "group.com.odudu.BeYou"

    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    // MARK: - App Intention

    func loadAppIntention() -> AppIntention {
        var intention = AppIntention()

        if let timesPerDay = sharedDefaults?.object(forKey: "intentionTimesPerDay") as? Int, timesPerDay > 0 {
            intention.timesPerDay = timesPerDay
        }

        if let minutesPerSession = sharedDefaults?.object(forKey: "intentionMinutesPerSession") as? Int, minutesPerSession > 0 {
            intention.minutesPerSession = minutesPerSession
        }

        if let data = sharedDefaults?.data(forKey: "perAppIntentions"),
           let decoded = try? JSONDecoder().decode([String: IndividualAppIntention].self, from: data) {
            intention.perAppIntentions = decoded
        }

        return intention
    }

    // MARK: - Usage Stats

    func loadUsageStats() -> AppUsageStats {
        var stats = AppUsageStats()

        stats.breakthroughsToday = sharedDefaults?.integer(forKey: "breakthroughsToday") ?? 0

        if let data = sharedDefaults?.data(forKey: "breakthroughsByApp"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            stats.breakthroughsByApp = decoded
        }

        return stats
    }

    // MARK: - Schedule-Specific Blocked Apps

    func saveScheduleBlockedApps(scheduleKey: String, blockedAppsData: Data) {
        print("💾 MONITOR-SHARED: Saving blocked apps for schedule: \(scheduleKey)")
        sharedDefaults?.set(blockedAppsData, forKey: "\(scheduleKey)_blockedApps")
        sharedDefaults?.synchronize()
    }

    func loadScheduleBlockedApps(scheduleKey: String) -> Data? {
        let data = sharedDefaults?.data(forKey: "\(scheduleKey)_blockedApps")
        print("💾 MONITOR-SHARED: Loading blocked apps for schedule: \(scheduleKey) - \(data != nil ? "Found" : "Not found")")
        return data
    }

    // MARK: - Active Schedule Tracking

    func addActiveSchedule(_ scheduleKey: String) {
        var active = loadActiveScheduleKeys()
        active.insert(scheduleKey)
        if let encoded = try? JSONEncoder().encode(Array(active)) {
            sharedDefaults?.set(encoded, forKey: "activeScheduleKeys")
            sharedDefaults?.synchronize()
        }
        print("💾 MONITOR-SHARED: Added active schedule: \(scheduleKey)")
    }

    func removeActiveSchedule(_ scheduleKey: String) {
        var active = loadActiveScheduleKeys()
        active.remove(scheduleKey)
        if let encoded = try? JSONEncoder().encode(Array(active)) {
            sharedDefaults?.set(encoded, forKey: "activeScheduleKeys")
            sharedDefaults?.synchronize()
        }
        print("💾 MONITOR-SHARED: Removed active schedule: \(scheduleKey)")
    }

    func loadActiveScheduleKeys() -> Set<String> {
        if let data = sharedDefaults?.data(forKey: "activeScheduleKeys"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return Set(decoded)
        }
        return []
    }

    // MARK: - Active Schedule Token Data (per-app checking)

    func addActiveScheduleTokens(_ tokens: [Data]) {
        var existing = loadActiveScheduleTokenData()
        for token in tokens {
            if !existing.contains(token) {
                existing.append(token)
            }
        }
        if let encoded = try? JSONEncoder().encode(existing) {
            sharedDefaults?.set(encoded, forKey: "activeScheduleTokenData")
            sharedDefaults?.synchronize()
        }
    }

    func removeActiveScheduleTokens(_ tokens: [Data]) {
        var existing = loadActiveScheduleTokenData()
        existing.removeAll { tokens.contains($0) }
        if let encoded = try? JSONEncoder().encode(existing) {
            sharedDefaults?.set(encoded, forKey: "activeScheduleTokenData")
            sharedDefaults?.synchronize()
        }
    }

    func loadActiveScheduleTokenData() -> [Data] {
        if let data = sharedDefaults?.data(forKey: "activeScheduleTokenData"),
           let decoded = try? JSONDecoder().decode([Data].self, from: data) {
            return decoded
        }
        return []
    }

    // MARK: - Pending Unlock Re-blocks

    func loadAllPendingReblocks() -> [String: Data] {
        if let data = sharedDefaults?.data(forKey: "pendingReblocks"),
           let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            return decoded
        }
        return [:]
    }

    func removePendingReblock(storeKey: String) {
        var pending = loadAllPendingReblocks()
        pending.removeValue(forKey: storeKey)
        if let encoded = try? JSONEncoder().encode(pending) {
            sharedDefaults?.set(encoded, forKey: "pendingReblocks")
            sharedDefaults?.synchronize()
        }
        print("💾 MONITOR-SHARED: Removed pending reblock for \(storeKey)")
    }

    /// Clear unlock state for an app after re-blocking
    func clearUnlockState(storeKey: String) {
        // Build a set of all possible keys for this app (storeKey + any mapped display names)
        var keysToRemove: Set<String> = [storeKey]

        // Load store key mapping to find display name <-> token key associations
        if let mappingData = sharedDefaults?.data(forKey: "storeKeyMapping"),
           let mapping = try? JSONDecoder().decode([String: String].self, from: mappingData) {
            // If storeKey is a token key (app_XXX), find its display name
            for (displayName, tokenKey) in mapping {
                if tokenKey == storeKey {
                    keysToRemove.insert(displayName)
                }
            }
            // If storeKey is a display name, find its token key
            if let tokenKey = mapping[storeKey] {
                keysToRemove.insert(tokenKey)
            }
        }

        print("💾 MONITOR-SHARED: Clearing unlock state for keys: \(keysToRemove)")

        // Load and update unlockedApps — remove ALL matching keys
        if let data = sharedDefaults?.data(forKey: "unlockedApps"),
           var decoded = try? JSONDecoder().decode([String].self, from: data) {
            decoded.removeAll { keysToRemove.contains($0) }
            if let encoded = try? JSONEncoder().encode(decoded) {
                sharedDefaults?.set(encoded, forKey: "unlockedApps")
            }
        }

        // Load and update unlockExpiryByApp — remove ALL matching keys
        if let data = sharedDefaults?.data(forKey: "unlockExpiryByApp"),
           var decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            for key in keysToRemove {
                decoded.removeValue(forKey: key)
            }
            if let encoded = try? JSONEncoder().encode(decoded) {
                sharedDefaults?.set(encoded, forKey: "unlockExpiryByApp")
            }
        }

        sharedDefaults?.synchronize()
        print("💾 MONITOR-SHARED: Cleared unlock state for \(storeKey) (checked \(keysToRemove.count) key variants)")
    }

    // MARK: - Meditation

    func loadMeditationAppSelection() -> Data? {
        return sharedDefaults?.data(forKey: "meditationAppSelection")
    }

    func saveMeditationBlockActive(_ active: Bool) {
        sharedDefaults?.set(active, forKey: "isMeditationBlockActive")
        sharedDefaults?.synchronize()
    }

    func loadMeditationTimes() -> [MeditationTime] {
        if let data = sharedDefaults?.data(forKey: "meditationTimes"),
           let decoded = try? JSONDecoder().decode([MeditationTime].self, from: data) {
            return decoded
        }
        return []
    }

    func loadMeditationCompletedForTime(_ timeKey: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "meditationDone_\(formatter.string(from: Date()))_\(timeKey)"
        return sharedDefaults?.bool(forKey: key) ?? false
    }

    func saveActiveMeditationTimeKey(_ timeKey: String?) {
        sharedDefaults?.set(timeKey, forKey: "activeMeditationTimeKey")
        sharedDefaults?.synchronize()
    }
}

// MARK: - Data Models (Extension Version)

struct AppIntention {
    var timesPerDay: Int = 10
    var minutesPerSession: Int = 5
    var perAppIntentions: [String: IndividualAppIntention] = [:]
}

struct IndividualAppIntention: Codable {
    var appName: String
    var bundleIdentifier: String?
    var appTokenData: Data?
    var timesPerDay: Int
    var minutesPerSession: Int
}

struct AppUsageStats {
    var breakthroughsToday: Int = 0
    var breakthroughsByApp: [String: Int] = [:]
}

struct MeditationTime: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var hour: Int
    var minute: Int
    var days: Set<Int>
}
