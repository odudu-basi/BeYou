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
    private var reblockTimers: [String: DispatchWorkItem] = [:]

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

        // Layer 1: DeviceActivityEvent — monitors app usage in the extension process.
        // When the user accumulates `duration` seconds of usage on this app,
        // eventDidReachThreshold fires in the monitor extension and re-blocks.
        // This works even if the main app is killed.
        scheduleUnlockReblockEvent(forKey: storeKey, token: token, duration: duration)

        // In-memory timer as fast-path (fires if app is alive)
        // Cancel any existing timer for this store key
        reblockTimers[storeKey]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            print("⏰ SCREEN TIME: Re-blocking \(key) after in-memory timeout")
            self?.blockApp(token: token, forKey: storeKey)
            self?.sharedData.removePendingReblock(storeKey: storeKey)
            // Stop the event monitor since we handled it
            self?.activityCenter.stopMonitoring([DeviceActivityName("unlock_\(storeKey)")])
            self?.reblockTimers.removeValue(forKey: storeKey)
        }
        reblockTimers[storeKey] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
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

        // Cancel any pending re-block timer so it doesn't re-block after deletion
        reblockTimers[storeKey]?.cancel()
        reblockTimers.removeValue(forKey: storeKey)
        print("🗑️ SCREEN TIME: Cancelled re-block timer for \(storeKey)")

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

    // MARK: - Re-apply Blocks on Launch

    /// Re-applies shields for all app intentions on app launch.
    /// This catches cases where the re-block timer (DispatchQueue.main.asyncAfter)
    /// never fired because iOS suspended/killed the app.
    func reapplyAllBlocks(appState: AppState) {
        guard authorizationStatus == .approved else {
            print("❌ SCREEN TIME: Not approved, cannot reapply blocks")
            return
        }

        print("🔒 SCREEN TIME: Reapplying blocks for all app intentions...")

        let intention = sharedData.loadAppIntention()
        var reblocked = 0

        for (key, appIntention) in intention.perAppIntentions {
            guard let tokenData = appIntention.appTokenData,
                  let token = try? JSONDecoder().decode(ApplicationToken.self, from: tokenData) else {
                continue
            }

            let storeKey = resolveStoreKey(from: key)

            // Check if this app is currently in an active unlock session
            if appState.isAppUnlocked(key) {
                // Still unlocked — re-schedule all fallback layers for remaining time
                if let expiry = appState.appUsageStats.unlockExpiryByApp[key] {
                    let remaining = expiry.timeIntervalSinceNow
                    if remaining > 0 {
                        print("⏰ SCREEN TIME: \(key) still unlocked, re-scheduling reblock in \(Int(remaining))s")
                        // Ensure pending reblock data exists for the monitor
                        if let tokenData = try? JSONEncoder().encode(token) {
                            sharedData.savePendingReblock(storeKey: storeKey, tokenData: tokenData)
                        }
                        // Layer 1: Usage-based event in monitor extension
                        scheduleUnlockReblockEvent(forKey: storeKey, token: token, duration: remaining)
                        // In-memory timer as fast-path (cancellable)
                        reblockTimers[storeKey]?.cancel()
                        let workItem = DispatchWorkItem { [weak self] in
                            print("⏰ SCREEN TIME: Re-blocking \(key) after resumed timer")
                            self?.blockApp(token: token, forKey: storeKey)
                            self?.sharedData.removePendingReblock(storeKey: storeKey)
                            self?.activityCenter.stopMonitoring([DeviceActivityName("unlock_\(storeKey)")])
                            self?.reblockTimers.removeValue(forKey: storeKey)
                        }
                        reblockTimers[storeKey] = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
                        continue
                    }
                }
                // Expiry passed while app was suspended — clear unlock state
                appState.appUsageStats.unlockedApps.remove(key)
                appState.appUsageStats.unlockExpiryByApp.removeValue(forKey: key)
                sharedData.removePendingReblock(storeKey: storeKey)
            }

            // App should be blocked — re-apply shield
            blockApp(token: token, forKey: storeKey)
            reblocked += 1
        }

        if reblocked > 0 {
            // Save updated unlock state directly (saveAllData is private to AppState)
            sharedData.saveUsageStats(appState.appUsageStats)
        }
        print("🔒 SCREEN TIME: Reapplied blocks for \(reblocked) apps")
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
