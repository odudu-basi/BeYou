import SwiftUI
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - DeviceActivity Names

@available(iOS 16.0, *)
extension DeviceActivityName {
    static let beforeBedSchedule = DeviceActivityName("beforeBedSchedule")
    static let morningSchedule = DeviceActivityName("morningSchedule")
    static let workSchedule = DeviceActivityName("workSchedule")
    static let dailyIntention = DeviceActivityName("dailyIntention")
}

@available(iOS 16.0, *)
class ScreenTimeManager: ObservableObject {
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var activitySelection = FamilyActivitySelection()

    private let center = AuthorizationCenter.shared
    private let store = ManagedSettingsStore() // Legacy: for backward compatibility
    private let activityCenter = DeviceActivityCenter()
    private let sharedData = SharedDataManager.shared

    // NEW: Named stores for independent app management
    // Key = app key (e.g., "app_123456789"), Value = that app's dedicated store
    private var appStores: [String: ManagedSettingsStore] = [:]

    // Cancellable re-block timers keyed by store key
    // Re-blocking is handled entirely by DeviceActivityEvent in the monitor extension

    enum AuthorizationStatus {
        case notDetermined
        case denied
        case approved
    }

    init() {
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run {
                updateAuthorizationStatus()
            }
        } catch {
            throw error
        }
    }

    func updateAuthorizationStatus() {
        switch center.authorizationStatus {
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .denied:
            authorizationStatus = .denied
        case .approved:
            authorizationStatus = .approved
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }

    // MARK: - App Blocking

    func blockSelectedApps() {
        print("🔒 SCREEN TIME: blockSelectedApps called")
        print("🔒 SCREEN TIME: Authorization status: \(authorizationStatus)")

        guard authorizationStatus == .approved else {
            print("❌ SCREEN TIME: Not approved! Cannot block apps")
            return
        }

        print("🔒 SCREEN TIME: Applying shields to \(activitySelection.applicationTokens.count) apps")
        store.shield.applications = activitySelection.applicationTokens
        store.shield.applicationCategories = .specific(activitySelection.categoryTokens)

        print("✅ SCREEN TIME: Shields applied successfully")

        // Save selection to shared storage
        sharedData.saveAppSelection(activitySelection)
    }

    func unblockAllApps() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    func temporarilyUnlockApps(for duration: TimeInterval) {
        // Temporarily remove shields
        unblockAllApps()

        // Re-apply shields after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.blockSelectedApps()
        }
    }

    // MARK: - Per-App Independent Blocking (NEW)

    /// Block a specific app using its own named store (completely independent)
    func blockApp(token: ApplicationToken, forKey key: String) {
        guard authorizationStatus == .approved else {
            print("❌ SCREEN TIME: Not approved! Cannot block app \(key)")
            return
        }

        print("🔒 SCREEN TIME: Blocking app independently - key: \(key)")

        // Get or create a named store for this specific app
        let namedStore = getOrCreateStore(forKey: key)

        // Block ONLY this app in its dedicated store
        namedStore.shield.applications = [token]

        // If this is a token-based key, save it for later mapping
        // (When shield displays, it will map display name -> token key)
        if key.hasPrefix("app_") {
            print("🔒 SCREEN TIME: Saved token-based store key: \(key)")
            // The mapping will be created by the shield extension when it first displays
        }

        print("✅ SCREEN TIME: App \(key) blocked independently")
    }

    /// Unblock a specific app by clearing its named store (doesn't affect other apps)
    func unblockApp(forKey key: String) {
        print("🔓 SCREEN TIME: Unlocking app independently - key: \(key)")

        // If key is a display name, look up the actual store key
        let storeKey = resolveStoreKey(from: key)
        print("🔓 SCREEN TIME: Resolved store key: \(storeKey)")

        // Get or create the store — after app restart, appStores is empty
        // but we can recreate the named store from the key
        let namedStore = getOrCreateStore(forKey: storeKey)

        // Remove shields from ONLY this app's store
        namedStore.shield.applications = nil
        namedStore.shield.applicationCategories = nil

        print("✅ SCREEN TIME: App \(key) unlocked independently")
    }

    /// Temporarily unlock a specific app for a duration (doesn't affect other apps)
    func temporarilyUnlockApp(forKey key: String, token: ApplicationToken, duration: TimeInterval) {
        print("⏰ SCREEN TIME: Temporarily unlocking \(key) for \(duration) seconds")

        // Resolve the store key (in case key is display name)
        let storeKey = resolveStoreKey(from: key)
        print("⏰ SCREEN TIME: Resolved store key: \(storeKey)")

        // Unblock this specific app from its named store
        unblockApp(forKey: key)

        // Safety: also remove this token from the default store in case it was
        // added there by a legacy blockSelectedApps() call during setup
        if var defaultApps = store.shield.applications {
            defaultApps.remove(token)
            store.shield.applications = defaultApps.isEmpty ? nil : defaultApps
            print("⏰ SCREEN TIME: Also cleared token from default store")
        }

        // Save the token data so the monitor extension can re-block this app
        if let tokenData = try? JSONEncoder().encode(token) {
            sharedData.savePendingReblock(storeKey: storeKey, tokenData: tokenData)
        }

        // DeviceActivityEvent — monitors app usage in the extension process.
        // When the user accumulates `duration` seconds of actual usage on this app,
        // eventDidReachThreshold fires in the monitor extension and re-blocks.
        // This works even if the main app is killed.
        scheduleUnlockReblockEvent(forKey: storeKey, token: token, duration: duration)
    }

    /// Schedule a DeviceActivityEvent to re-block an app after unlock usage reaches the limit.
    /// Uses eventDidReachThreshold which fires in the monitor extension — works even if app is killed.
    private func scheduleUnlockReblockEvent(forKey storeKey: String, token: ApplicationToken, duration: TimeInterval) {
        let activityName = DeviceActivityName("unlock_\(storeKey)")

        // Create a full-day schedule so the event has a window to fire in
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Create an event that fires when this app's usage reaches the unlock duration
        let unlockMinutes = Int(duration / 60)
        let eventName = DeviceActivityEvent.Name("unlock_event_\(storeKey)")
        let event = DeviceActivityEvent(
            applications: [token],
            threshold: DateComponents(minute: max(unlockMinutes, 1))
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [eventName: event]

        // Add a 1-minute warning event if there's enough time (> 1 minute)
        let warningMinutes = unlockMinutes - 1
        if warningMinutes >= 1 {
            let warningEventName = DeviceActivityEvent.Name("unlock_warning_\(storeKey)")
            let warningEvent = DeviceActivityEvent(
                applications: [token],
                threshold: DateComponents(minute: warningMinutes)
            )
            events[warningEventName] = warningEvent
        }

        do {
            activityCenter.stopMonitoring([activityName])
            try activityCenter.startMonitoring(
                activityName,
                during: schedule,
                events: events
            )
            print("⏰ SCREEN TIME: Scheduled usage-based re-block for \(storeKey) (\(unlockMinutes) min threshold, warning at \(warningMinutes) min)")
        } catch {
            print("❌ SCREEN TIME: Failed to schedule usage event: \(error)")
        }
    }

    /// Resolve the actual store key from a display name or token key
    /// If key is a display name, look up the mapping to get the token key
    /// If key is already a token key, return it as-is
    private func resolveStoreKey(from key: String) -> String {
        // If it's already a token key, return it
        if key.hasPrefix("app_") {
            return key
        }

        // Otherwise, it's a display name - look up the mapping
        let mapping = sharedData.loadStoreKeyMapping()
        if let storeKey = mapping[key] {
            print("🔍 SCREEN TIME: Mapped '\(key)' -> '\(storeKey)'")
            return storeKey
        }

        // Fallback: return the key as-is (for backward compatibility)
        print("⚠️ SCREEN TIME: No mapping found for '\(key)', using as-is")
        return key
    }

    /// Get or create a named store for a specific app
    private func getOrCreateStore(forKey key: String) -> ManagedSettingsStore {
        if let existingStore = appStores[key] {
            return existingStore
        }

        // Create new named store for this app
        let newStore = ManagedSettingsStore(named: ManagedSettingsStore.Name(key))
        appStores[key] = newStore
        print("📦 SCREEN TIME: Created new store for \(key)")
        return newStore
    }

    /// Remove a specific app's store completely (when deleting intention)
    func removeAppStore(forKey key: String) {
        print("🗑️ SCREEN TIME: Removing store for \(key)")

        // Resolve the store key
        let storeKey = resolveStoreKey(from: key)
        print("🗑️ SCREEN TIME: Resolved store key: \(storeKey)")

        // Stop any pending re-block monitors

        // Stop the DeviceActivity monitor that would re-block from the extension
        activityCenter.stopMonitoring([DeviceActivityName("unlock_\(storeKey)")])
        print("🗑️ SCREEN TIME: Stopped activity monitor for \(storeKey)")

        // Remove pending reblock data from shared storage
        sharedData.removePendingReblock(storeKey: storeKey)
        print("🗑️ SCREEN TIME: Removed pending reblock for \(storeKey)")

        // Clear shields
        unblockApp(forKey: key)

        // Remove from dictionary
        appStores.removeValue(forKey: storeKey)

        // Clean up the mapping if this was a display name
        if !key.hasPrefix("app_") {
            var mapping = sharedData.loadStoreKeyMapping()
            mapping.removeValue(forKey: key)
            sharedData.saveStoreKeyMapping(mapping)
            print("🗑️ SCREEN TIME: Removed mapping for '\(key)'")
        }
    }

    // Re-blocking after unlock is handled entirely by DeviceActivityEvent in the monitor extension.
    // No in-memory timers or reapplyAllBlocks needed — the extension survives app kills and reboots.

    // MARK: - Meditation Blocking

    private let meditationStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("meditation"))

    /// Activate meditation blocks for all selected meditation apps
    func activateMeditationBlock(selection: FamilyActivitySelection) {
        guard authorizationStatus == .approved else { return }

        // Block apps
        if !selection.applicationTokens.isEmpty {
            meditationStore.shield.applications = selection.applicationTokens
        }

        // Block categories
        if !selection.categoryTokens.isEmpty {
            meditationStore.shield.applicationCategories = .specific(selection.categoryTokens)
        }

        // Save token data for shield extensions to check
        let tokenDataArray = selection.applicationTokens.compactMap { token -> Data? in
            try? JSONEncoder().encode(token)
        }
        sharedData.saveMeditationBlockedTokens(tokenDataArray)
        sharedData.saveMeditationBlockActive(true)

        print("🧘 MEDITATION: Blocked \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
    }

    /// Remove meditation blocks (after completing meditation intervention)
    func deactivateMeditationBlock() {
        meditationStore.clearAllSettings()
        sharedData.saveMeditationBlockActive(false)
        print("🧘 MEDITATION: All meditation blocks removed")
    }

    // MARK: - App Block (block-all-except-allowed, engaged when an alarm fires)

    private let appBlockStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("appBlock"))

    /// Blocks every app except the user's allow-list. Engaged when an alarm fires;
    /// stays until the user completes the unblock flow.
    func activateAppBlock() {
        guard authorizationStatus == .approved else {
            print("🔒 APP BLOCK: Not authorized — block not applied")
            return
        }
        let allowed = AppBlockStore.allowedSelection.applicationTokens
        appBlockStore.shield.applicationCategories = .all(except: allowed)
        appBlockStore.application.denyAppRemoval = AppBlockStore.denyDeletion ? true : nil
        AppBlockStore.isActive = true
        sharedData.saveAppBlockActive(true) // App Group flag for the shield extensions
        print("🔒 APP BLOCK: Activated (allowing \(allowed.count) apps)")
    }

    /// Removes the App Block (after the unblock intervention, or when the feature is turned off).
    func deactivateAppBlock() {
        appBlockStore.clearAllSettings()
        AppBlockStore.isActive = false
        sharedData.saveAppBlockActive(false) // App Group flag for the shield extensions
        print("🔓 APP BLOCK: Deactivated")
    }

    /// Re-applies the allow-list / deny-deletion if the block is currently active
    /// (e.g. the user changed the allowed apps while blocking).
    func refreshAppBlockIfActive() {
        if AppBlockStore.isActive { activateAppBlock() }
    }

    /// Check if meditation block should be active based on current time and schedules.
    /// Only the most recent passed meditation time matters. Each time is tracked independently.
    func checkMeditationSchedule() {
        let times = sharedData.loadMeditationTimes()
        guard !times.isEmpty else {
            if sharedData.loadMeditationBlockActive() {
                deactivateMeditationBlock()
            }
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now) // 1 = Sunday
        let currentTotalMinutes = currentHour * 60 + currentMinute

        // Find the most recent meditation time that has passed today
        var mostRecentTime: MeditationTime?
        var mostRecentMinutes: Int = -1

        for time in times {
            guard time.days.contains(currentWeekday) else { continue }
            let scheduledMinutes = time.hour * 60 + time.minute
            if currentTotalMinutes >= scheduledMinutes && scheduledMinutes > mostRecentMinutes {
                mostRecentMinutes = scheduledMinutes
                mostRecentTime = time
            }
        }

        guard let activeTime = mostRecentTime else {
            // No meditation time has passed yet today — clear blocks
            if sharedData.loadMeditationBlockActive() {
                deactivateMeditationBlock()
            }
            return
        }

        // Check if this specific time slot has been completed
        let timeKey = String(format: "%02d:%02d", activeTime.hour, activeTime.minute)
        if sharedData.loadMeditationCompletedForTime(timeKey) {
            // This time slot is done — unblock
            if sharedData.loadMeditationBlockActive() {
                deactivateMeditationBlock()
            }
        } else {
            // This time slot is NOT done — block
            sharedData.saveActiveMeditationTimeKey(timeKey)
            if !sharedData.loadMeditationBlockActive() {
                if let selectionData = UserDefaults.standard.data(forKey: "meditationAppSelection"),
                   let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) {
                    activateMeditationBlock(selection: selection)
                }
            }
        }
    }

    /// Register DeviceActivitySchedules for all meditation times so blocks activate in background
    func registerMeditationSchedules(times: [MeditationTime]) {
        // Remove old meditation schedules
        let existingActivities = activityCenter.activities
        let meditationActivities = existingActivities.filter { "\($0)".contains("meditation_") }
        if !meditationActivities.isEmpty {
            activityCenter.stopMonitoring(meditationActivities)
            print("🧘 MEDITATION: Stopped \(meditationActivities.count) old meditation schedules")
        }

        for time in times {
            for day in time.days {
                let activityName = DeviceActivityName("meditation_\(time.id.uuidString)_\(day)")

                let startComponents = DateComponents(hour: time.hour, minute: time.minute, weekday: day)
                // 24-hour window for reliable iOS triggering
                let endHour = (time.hour + 23) % 24
                let endMinute = time.minute > 0 ? time.minute - 1 : 59
                let endComponents = DateComponents(hour: endHour, minute: endMinute, weekday: day)

                let schedule = DeviceActivitySchedule(
                    intervalStart: startComponents,
                    intervalEnd: endComponents,
                    repeats: true
                )

                do {
                    try activityCenter.startMonitoring(activityName, during: schedule)
                    print("🧘 MEDITATION: Registered schedule for \(time.name) on day \(day) at \(time.hour):\(String(format: "%02d", time.minute))")
                } catch {
                    print("🧘 MEDITATION: Failed to register schedule: \(error)")
                }
            }
        }
    }

    // MARK: - Scheduled Blocking (Disconnect Times)

    func setupDisconnectSchedule(type: String, startTime: Date, endTime: Date, blockedAppsData: Data? = nil, scheduleID: String? = nil) {
        guard authorizationStatus == .approved else { return }

        let schedule: DeviceActivitySchedule
        let calendar = Calendar.current

        // Extract hour and minute from dates
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let endHour = endComponents.hour,
              let endMinute = endComponents.minute else {
            return
        }

        // Create schedule
        let startTime = DateComponents(hour: startHour, minute: startMinute)
        let endTime = DateComponents(hour: endHour, minute: endMinute)

        schedule = DeviceActivitySchedule(
            intervalStart: startTime,
            intervalEnd: endTime,
            repeats: true
        )

        // Create unique activity name based on schedule ID or type
        let activityName: DeviceActivityName
        let scheduleKey: String

        if let id = scheduleID {
            // Use schedule ID for custom schedules
            scheduleKey = "schedule_\(id)"
            activityName = DeviceActivityName(scheduleKey)
        } else {
            // Legacy: Use predefined names for backward compatibility
            switch type {
            case "Morning":
                activityName = .morningSchedule
                scheduleKey = "morningSchedule"
            case "Before Bed":
                activityName = .beforeBedSchedule
                scheduleKey = "beforeBedSchedule"
            case "At Work":
                activityName = .workSchedule
                scheduleKey = "workSchedule"
            default:
                return
            }
        }

        // Save schedule-specific blocked apps to shared storage
        if let blockedData = blockedAppsData {
            print("🔒 SCREEN TIME: ========================================")
            print("🔒 SCREEN TIME: Saving blocked apps for schedule")
            print("🔒 SCREEN TIME: Schedule key: \(scheduleKey)")
            print("🔒 SCREEN TIME: Schedule ID: \(scheduleID ?? "none")")
            print("🔒 SCREEN TIME: Data size: \(blockedData.count) bytes")
            print("🔒 SCREEN TIME: Will save to key: \(scheduleKey)_blockedApps")
            print("🔒 SCREEN TIME: ========================================")
            sharedData.saveScheduleBlockedApps(scheduleKey: scheduleKey, blockedAppsData: blockedData)
        }

        // Start monitoring
        do {
            try activityCenter.startMonitoring(activityName, during: schedule)
            print("✅ SCREEN TIME: Started monitoring schedule: \(scheduleKey)")

            // Schedule notification 10 minutes before disconnect time starts
            if let scheduleStartDate = calendar.date(from: startTime) {
                NotificationManager.shared.scheduleDisconnectWarning(
                    type: type,
                    startTime: scheduleStartDate
                )
            }
        } catch {
            print("❌ SCREEN TIME: Failed to start monitoring: \(error)")
        }
    }

    func stopAllSchedules() {
        activityCenter.stopMonitoring([.morningSchedule, .beforeBedSchedule, .workSchedule, .dailyIntention])

        // Cancel all disconnect warning notifications
        NotificationManager.shared.cancelDisconnectWarning(type: "Morning")
        NotificationManager.shared.cancelDisconnectWarning(type: "Before Bed")
        NotificationManager.shared.cancelDisconnectWarning(type: "At Work")
    }

    /// Stop monitoring a specific schedule by its UUID
    func stopSchedule(id: String) {
        let scheduleKey = "schedule_\(id)"
        let activityName = DeviceActivityName(scheduleKey)
        activityCenter.stopMonitoring([activityName])
        print("🔒 SCREEN TIME: Stopped monitoring schedule: \(scheduleKey)")

        // Clear the schedule-specific ManagedSettingsStore (removes shields)
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: scheduleKey))
        store.clearAllSettings()
        print("🔒 SCREEN TIME: Cleared store for schedule: \(scheduleKey)")

        // Clean up shared data so extensions know this schedule is no longer active
        sharedData.removeActiveSchedule(scheduleKey)
        sharedData.removeActiveScheduleTokensForSchedule(scheduleKey)
        sharedData.removeScheduleBlockedApps(scheduleKey: scheduleKey)
        print("🔒 SCREEN TIME: Cleaned up shared data for schedule: \(scheduleKey)")
    }

    // MARK: - Daily Intention Monitoring

    func setupDailyIntentionMonitoring(timesPerDay: Int) {
        guard authorizationStatus == .approved else { return }

        // Create a 24-hour schedule
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // This would need DeviceActivityEvent configuration
        // to track when apps are opened X times

        do {
            try activityCenter.startMonitoring(.dailyIntention, during: schedule)
        } catch {
            print("Failed to start intention monitoring: \(error)")
        }
    }

    // MARK: - Helpers

    func hasSelectedApps() -> Bool {
        !activitySelection.applicationTokens.isEmpty
    }

    func checkAndApplyBlocking(appState: AppState, for appName: String? = nil) {
        // Per-app blocking logic
        if let app = appName {
            // Check if this specific app's unlock has expired
            if appState.checkIfUnlockExpired(for: app) {
                // Re-apply shields for this app
                blockSelectedApps()
            } else if appState.isAppUnlocked(app) {
                // This app is currently unlocked - remove shields
                unblockAllApps()
            } else {
                // Check if user exceeded daily limit for this app
                let breakthroughs = appState.getAppBreakthroughs(app)
                let limit = appState.getAppLimit(app)

                if breakthroughs >= limit {
                    // Apply shields
                    blockSelectedApps()
                }
            }
        } else {
            // Legacy: Check overall unlock status
            if appState.checkIfUnlockExpired() {
                // Re-apply shields
                blockSelectedApps()
            } else if appState.appUsageStats.isUnlocked {
                // Currently unlocked - remove shields
                unblockAllApps()
            } else {
                // Check if ANY app exceeded its daily limit
                var shouldBlock = false
                for (app, breakthroughs) in appState.appUsageStats.breakthroughsByApp {
                    let limit = appState.getAppLimit(app)
                    if breakthroughs >= limit {
                        shouldBlock = true
                        break
                    }
                }

                if shouldBlock {
                    blockSelectedApps()
                }
            }
        }
    }

    // Check if any app is currently unlocked
    func hasAnyUnlockedApps(appState: AppState) -> Bool {
        return !appState.appUsageStats.unlockedApps.isEmpty
    }

    // Get list of apps that should be blocked (exceeded their limit)
    func getAppsToBlock(appState: AppState) -> [String] {
        var appsToBlock: [String] = []

        for (app, breakthroughs) in appState.appUsageStats.breakthroughsByApp {
            let limit = appState.getAppLimit(app)
            if breakthroughs >= limit && !appState.isAppUnlocked(app) {
                appsToBlock.append(app)
            }
        }

        return appsToBlock
    }
}
