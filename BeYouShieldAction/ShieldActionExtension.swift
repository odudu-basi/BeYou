//
//  ShieldActionExtension.swift
//  BeYouShieldAction
//
//  Created by Oduduabasi Victor on 3/9/26.
//

import ManagedSettings
import Foundation
import UserNotifications

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldActionExtension: ShieldActionDelegate {

    private let sharedData = SharedDataManager.shared

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("⚡ SHIELD ACTION: Button pressed - \(action)")

        // Resolve app name by matching the token (same logic as ShieldConfiguration)
        let appName = resolveAppName(for: application)
        print("⚡ SHIELD ACTION: Resolved app name = \(appName)")

        // Determine block type (intention vs schedule)
        let blockType = resolveBlockType(for: application, appName: appName)
        print("⚡ SHIELD ACTION: Block type = \(blockType)")

        switch action {
        case .primaryButtonPressed:
            if blockType == "appBlock" {
                // App Block shield is informational — Close just dismisses to home.
                print("⚡ SHIELD ACTION: App Block - Close pressed")
                completionHandler(.close)
            } else if blockType == "meditation" {
                // Meditation shield is informational — just close
                print("⚡ SHIELD ACTION: Meditation - Close pressed")
                completionHandler(.close)
            } else if blockType == "schedule" {
                // Schedule block flow
                let showInstructions = sharedData.loadScheduleShowInstructions()
                if showInstructions {
                    // State 2: "Close" button - dismiss shield, clear flag, keep block active
                    print("⚡ SHIELD ACTION: Schedule - Close pressed (instructions were shown)")
                    sharedData.saveScheduleShowInstructions(false)
                    completionHandler(.defer) // Dismiss but keep block — shield returns on next tap
                } else {
                    // State 1: "Be Focused" button - dismiss shield, go back to home
                    print("⚡ SHIELD ACTION: Schedule - Be Focused pressed, dismissing")
                    completionHandler(.defer) // Dismiss but keep block — user returns to home screen
                }
            } else {
                // Intention block flow — two-step UI (like schedule flow)
                let isAlreadyActive = sharedData.loadInterventionActive()

                if !isAlreadyActive {
                    // STATE 1 → STATE 2: "Continue" pressed for the first time
                    // Same pattern as schedule "Open?" flow — save state, defer, shield reappears with new content
                    print("⚡ SHIELD ACTION: Continue pressed — transitioning to State 2")

                    // Save intervention state
                    sharedData.savePendingAppToUnlock(appName)
                    sharedData.saveInterventionActive(true)
                    sharedData.saveBlockType(blockType)
                    sharedData.forceSynchronize()
                    print("⚡ SHIELD ACTION: State saved and synchronized")

                    // Send Darwin notification (instant if app is in foreground)
                    sendDarwinNotification()

                    // Schedule local notification (works even if app is killed)
                    scheduleInterventionNotification(appName: appName)

                    // Defer — shield dismisses; it reappears with State 2 content on next tap
                    // (same as schedule "Open?" → "How to Unblock" flow)
                    completionHandler(.defer)
                } else {
                    // STATE 2: "Resend Notification" pressed
                    print("⚡ SHIELD ACTION: Resend notification pressed")

                    // Send Darwin notification (instant if app is in foreground)
                    sendDarwinNotification()

                    // Re-schedule local notification
                    scheduleInterventionNotification(appName: appName)

                    // Defer — shield reappears immediately since app is still blocked
                    completionHandler(.defer)
                }
            }

        case .secondaryButtonPressed:
            if blockType == "schedule" {
                // "Open?" pressed - save instructions flag, then defer so shield re-renders with instructions
                print("⚡ SHIELD ACTION: Schedule - Open? pressed, saving instructions flag")
                sharedData.saveScheduleShowInstructions(true)
                completionHandler(.defer) // Dismiss shield; it reappears with instructions on next tap
            } else {
                // "Nevermind" pressed (existing behavior)
                print("⚡ SHIELD ACTION: Secondary button (Nevermind) pressed")

                // Clear intervention state
                sharedData.saveInterventionActive(false)
                sharedData.savePendingAppToUnlock(nil)

                // Record that user chose "Nevermind" (good for discipline score)
                sharedData.recordNevermind()

                print("⚡ SHIELD ACTION: Cleared intervention state - user chose Nevermind")
                completionHandler(.close)
            }

        @unknown default:
            print("⚡ SHIELD ACTION: Unknown action")
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("⚡ SHIELD ACTION: Web domain button pressed")

        switch action {
        case .primaryButtonPressed:
            // Same logic for web domains
            sharedData.saveInterventionActive(true)
            sendDarwinNotification()
            scheduleInterventionNotification(appName: "the app")
            completionHandler(.close)

        case .secondaryButtonPressed:
            sharedData.saveInterventionActive(false)
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("⚡ SHIELD ACTION: Category button pressed")

        switch action {
        case .primaryButtonPressed:
            sharedData.saveInterventionActive(true)
            sendDarwinNotification()
            scheduleInterventionNotification(appName: "the app")
            completionHandler(.close)

        case .secondaryButtonPressed:
            sharedData.saveInterventionActive(false)
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - App Name Resolution

    /// Resolves the app name from the ApplicationToken by matching against stored intentions
    /// This returns the key from the perAppIntentions dictionary (should be migrated display name by this point)
    private func resolveAppName(for application: ApplicationToken) -> String {
        print("⚡ SHIELD ACTION: Starting app name resolution...")

        // Load intentions and storeKeyMapping from shared storage
        let intention = sharedData.loadAppIntention()
        let storeKeyMapping = sharedData.loadStoreKeyMapping()
        print("⚡ SHIELD ACTION: Loaded \(intention.perAppIntentions.count) intentions, \(storeKeyMapping.count) mappings")

        // Build reverse mapping: tokenKey -> displayName
        var reverseMapping: [String: String] = [:]
        for (displayName, tokenKey) in storeKeyMapping {
            reverseMapping[tokenKey] = displayName
        }

        // Try to match the application token to stored tokens
        if let currentAppData = try? JSONEncoder().encode(application) {
            print("⚡ SHIELD ACTION: ✅ Successfully encoded current app token (\(currentAppData.count) bytes)")

            // Look through all intentions to find matching token
            for (key, appIntention) in intention.perAppIntentions {
                if let storedTokenData = appIntention.appTokenData {
                    // Compare the token data
                    if currentAppData == storedTokenData {
                        if key.hasPrefix("app_") {
                            // Key hasn't been migrated yet — resolve display name
                            // 1. Check reverse storeKeyMapping (most reliable)
                            if let displayName = reverseMapping[key], !displayName.isEmpty {
                                print("⚡ SHIELD ACTION: ✅ MATCH! Resolved via storeKeyMapping: \(key) -> \(displayName)")
                                return displayName
                            }
                            // 2. Check if appName field has a real name (not a token key)
                            if !appIntention.appName.isEmpty && !appIntention.appName.hasPrefix("app_") {
                                print("⚡ SHIELD ACTION: ✅ MATCH! Resolved via appName field: \(appIntention.appName)")
                                return appIntention.appName
                            }
                            // 3. Return the token key itself — InterventionSheet can resolve it
                            // via token scan. Using "this app" would break matching downstream.
                            print("⚡ SHIELD ACTION: ✅ MATCH! No display name yet, returning token key: \(key)")
                            return key
                        } else {
                            // Key is already the display name (migration happened)
                            print("⚡ SHIELD ACTION: ✅ MATCH! Display name key: \(key)")
                            return key
                        }
                    }
                }
            }

            print("⚡ SHIELD ACTION: ❌ No matching token found")
        } else {
            print("⚡ SHIELD ACTION: ❌ Failed to encode current app token")
        }

        // Fallback: If there's only one intention, use it
        if intention.perAppIntentions.count == 1,
           let singleKey = intention.perAppIntentions.keys.first {
            if !singleKey.hasPrefix("app_") {
                print("⚡ SHIELD ACTION: Using single intention display name: \(singleKey)")
                return singleKey
            }
            // Single intention but still a token key — check reverse mapping
            if let displayName = reverseMapping[singleKey], !displayName.isEmpty {
                print("⚡ SHIELD ACTION: Using single intention via mapping: \(displayName)")
                return displayName
            }
            // Return the token key — better than "this app" for downstream matching
            print("⚡ SHIELD ACTION: Using single intention token key: \(singleKey)")
            return singleKey
        }

        // Last resort fallback — no intentions found at all
        print("⚡ SHIELD ACTION: ⚠️ No intentions found, using fallback 'this app'")
        return "this app"
    }

    // MARK: - Block Type Resolution

    /// Determines whether this block is from an app intention or a scheduled session
    /// Checks if THIS SPECIFIC APP is in an active schedule's blocked list
    private func resolveBlockType(for application: ApplicationToken, appName: String) -> String {
        // App Block blocks every app — highest priority.
        if sharedData.loadAppBlockActive() {
            print("⚡ SHIELD ACTION: App block is active — using appBlock block type")
            return "appBlock"
        }

        // Check meditation next (next highest priority)
        // If meditation block is active, all blocked apps use meditation type
        let isMeditationActive = sharedData.loadMeditationBlockActive()
        if isMeditationActive {
            print("⚡ SHIELD ACTION: Meditation block is active — using meditation block type")
            return "meditation"
        }

        // Check if this specific app is in an active schedule's blocked list
        let isAppInSchedule: Bool
        if let currentAppData = try? JSONEncoder().encode(application) {
            let activeTokens = sharedData.loadActiveScheduleTokenData()
            isAppInSchedule = activeTokens.contains(currentAppData)
        } else {
            isAppInSchedule = false
        }

        let intention = sharedData.loadAppIntention()

        // Check if this app has a per-app intention
        var hasAppIntention = intention.perAppIntentions[appName] != nil
        if !hasAppIntention, let currentAppData = try? JSONEncoder().encode(application) {
            for (_, appIntention) in intention.perAppIntentions {
                if let storedTokenData = appIntention.appTokenData, currentAppData == storedTokenData {
                    hasAppIntention = true
                    break
                }
            }
        }

        if isAppInSchedule {
            print("⚡ SHIELD ACTION: App is in active schedule — using schedule block type")
            return "schedule"
        } else if hasAppIntention {
            print("⚡ SHIELD ACTION: App has intention — using intention block type")
            return "intention"
        } else {
            print("⚡ SHIELD ACTION: No specific match, defaulting to intention")
            return "intention"
        }
    }

    // MARK: - Force Shield Re-render

    /// Forces the shield to re-render by briefly removing and re-adding the shield
    /// for this app. This makes iOS re-request the configuration from
    /// ShieldConfigurationExtension, which reads the updated shared storage state.
    private func forceShieldRerender(for application: ApplicationToken) {
        // Find the store key for this app
        let storeKey = resolveStoreKey(for: application)
        print("⚡ SHIELD ACTION: Force re-render - store key: \(storeKey)")

        // Get or create the named store for this app
        let namedStore = ManagedSettingsStore(named: ManagedSettingsStore.Name(storeKey))

        // Remove the shield
        namedStore.shield.applications = nil
        print("⚡ SHIELD ACTION: Shield cleared for re-render")

        // Wait for UserDefaults to sync across processes before re-adding.
        // Without this delay, ShieldConfigurationExtension reads stale state
        // and renders the old "Continue" button instead of "Resend Notification".
        Thread.sleep(forTimeInterval: 0.5)

        // Re-add the shield — iOS will re-request config from ShieldConfigurationExtension
        namedStore.shield.applications = [application]
        print("⚡ SHIELD ACTION: Shield re-added after sync delay — should trigger config re-request")
    }

    /// Finds the ManagedSettingsStore key for a given ApplicationToken
    private func resolveStoreKey(for application: ApplicationToken) -> String {
        let intention = sharedData.loadAppIntention()

        // Try to match token data to find the store key
        if let currentAppData = try? JSONEncoder().encode(application) {
            for (key, appIntention) in intention.perAppIntentions {
                if let storedTokenData = appIntention.appTokenData,
                   currentAppData == storedTokenData {
                    // Found it — return the key (this is the store name)
                    print("⚡ SHIELD ACTION: Resolved store key via token match: \(key)")
                    return key
                }
            }
        }

        // Fallback: if only one intention, use its key
        if let singleKey = intention.perAppIntentions.keys.first {
            print("⚡ SHIELD ACTION: Using single intention key as store key: \(singleKey)")
            return singleKey
        }

        // Last resort
        print("⚡ SHIELD ACTION: ⚠️ Could not resolve store key, using fallback")
        return "app_unknown"
    }

    // MARK: - Local Notification

    /// Schedules a local notification to open the BeYou app for intervention
    /// This works even if the main app is killed — iOS delivers it from the system
    private func scheduleInterventionNotification(appName: String) {
        let sanitizedName = appName.hasPrefix("app_") ? "the app" : appName

        let content = UNMutableNotificationContent()
        content.title = "Complete Your Mindful Unlock"
        content.body = "Tap to complete your intervention for \(sanitizedName)"
        content.sound = .default
        content.categoryIdentifier = "INTERVENTION_NOTIFICATION"
        content.userInfo = [
            "appName": sanitizedName,
            "action": "openIntervention",
            "deepLink": "beyou://intervention"
        ]

        // Fire after 1 second delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "intervention_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚡ SHIELD ACTION: ❌ Failed to schedule local notification: \(error)")
            } else {
                print("⚡ SHIELD ACTION: ✅ Local intervention notification scheduled")
            }
        }
    }

    // MARK: - Darwin Notification

    /// Sends a Darwin notification to wake the main app (backup for when app is already running)
    private func sendDarwinNotification() {
        let notificationName = "com.odudu.BeYou.unlockRequest" as CFString

        // Send Darwin notification
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(notificationName), nil, nil, true)

        print("⚡ SHIELD ACTION: Darwin notification sent: \(notificationName)")
    }
}

// MARK: - SharedDataManager (Extension Version)

class SharedDataManager {
    static let shared = SharedDataManager()
    private let appGroupIdentifier = "group.com.odudu.BeYou"

    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {
        if sharedDefaults != nil {
            print("⚡ SHARED: App Groups accessible")
        } else {
            print("⚡ SHARED: ❌ App Groups NOT accessible!")
        }
    }

    // MARK: - Pending App to Unlock

    func savePendingAppToUnlock(_ appName: String?) {
        print("⚡ SHARED: Saving pending app: \(appName ?? "nil")")
        sharedDefaults?.set(appName, forKey: "pendingAppToUnlock")
        let success = sharedDefaults?.synchronize() ?? false
        print("⚡ SHARED: Save synchronize result: \(success)")
    }

    func loadPendingAppToUnlock() -> String? {
        let appName = sharedDefaults?.string(forKey: "pendingAppToUnlock")
        print("⚡ SHARED: Loading pending app: \(appName ?? "nil")")
        return appName
    }

    // MARK: - Intervention State

    func saveInterventionActive(_ isActive: Bool) {
        print("⚡ SHARED: Saving intervention active: \(isActive)")
        sharedDefaults?.set(isActive, forKey: "isInterventionActive")
        let success = sharedDefaults?.synchronize() ?? false
        print("⚡ SHARED: Save synchronize result: \(success)")
    }

    func loadInterventionActive() -> Bool {
        let isActive = sharedDefaults?.bool(forKey: "isInterventionActive") ?? false
        print("⚡ SHARED: Loading intervention active: \(isActive)")
        return isActive
    }

    // MARK: - Nevermind Tracking

    func recordNevermind() {
        let currentCount = sharedDefaults?.integer(forKey: "nevermindCount") ?? 0
        sharedDefaults?.set(currentCount + 1, forKey: "nevermindCount")
        sharedDefaults?.synchronize()
        print("⚡ SHARED: Recorded Nevermind - count now: \(currentCount + 1)")
    }

    // MARK: - App Intention Loading

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
            print("⚡ SHARED: Loaded \(decoded.count) per-app intentions")
        }

        return intention
    }

    // MARK: - Time Waster Apps

    func loadTimeWasterApps() -> [String] {
        if let data = sharedDefaults?.data(forKey: "timeWasterApps"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            print("⚡ SHARED: Loaded \(decoded.count) time waster apps")
            return decoded
        }
        print("⚡ SHARED: No time waster apps found")
        return []
    }

    // MARK: - Schedule Shield Instructions State

    func saveScheduleShowInstructions(_ show: Bool) {
        sharedDefaults?.set(show, forKey: "scheduleShowInstructions")
        sharedDefaults?.synchronize()
    }

    func loadScheduleShowInstructions() -> Bool {
        return sharedDefaults?.bool(forKey: "scheduleShowInstructions") ?? false
    }

    // MARK: - Active Schedule Tracking

    func isAnyScheduleActive() -> Bool {
        if let data = sharedDefaults?.data(forKey: "activeScheduleKeys"),
           let decoded = try? JSONDecoder().decode([String].self, from: data),
           !decoded.isEmpty {
            return true
        }
        return false
    }

    func loadActiveScheduleTokenData() -> [Data] {
        if let data = sharedDefaults?.data(forKey: "activeScheduleTokenData"),
           let decoded = try? JSONDecoder().decode([Data].self, from: data) {
            return decoded
        }
        return []
    }

    // MARK: - Force Synchronize

    func forceSynchronize() {
        sharedDefaults?.synchronize()
    }

    // MARK: - Store Key Mapping

    func loadStoreKeyMapping() -> [String: String] {
        if let data = sharedDefaults?.data(forKey: "storeKeyMapping"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            return decoded
        }
        return [:]
    }

    // MARK: - Meditation Block

    func loadMeditationBlockActive() -> Bool {
        return sharedDefaults?.bool(forKey: "isMeditationBlockActive") ?? false
    }

    func loadAppBlockActive() -> Bool {
        return sharedDefaults?.bool(forKey: "isAppBlockActive") ?? false
    }

    func isAppInMeditationBlock(_ tokenData: Data) -> Bool {
        if let data = sharedDefaults?.data(forKey: "meditationBlockedTokens"),
           let decoded = try? JSONDecoder().decode([Data].self, from: data) {
            return decoded.contains(tokenData)
        }
        return false
    }

    // MARK: - Block Type

    func saveBlockType(_ type: String) {
        print("⚡ SHARED: Saving block type: \(type)")
        sharedDefaults?.set(type, forKey: "currentBlockType")
        sharedDefaults?.synchronize()
    }

    func loadBlockType() -> String {
        let type = sharedDefaults?.string(forKey: "currentBlockType") ?? "intention"
        print("⚡ SHARED: Loading block type: \(type)")
        return type
    }

}

// MARK: - Data Models

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
