//
//  ShieldConfigurationExtension.swift
//  BeYouShieldConfiguration
//
//  Created by Oduduabasi Victor on 3/8/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let sharedData = SharedDataManager.shared

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        print("🛡️ SHIELD: Configuration requested for app")

        // Force refresh from disk - extensions can have stale UserDefaults cache
        sharedData.sharedDefaults?.synchronize()

        if sharedData.sharedDefaults != nil {
            print("🛡️ SHIELD: ✅ Shared UserDefaults accessible")
        } else {
            print("🛡️ SHIELD: ❌ Shared UserDefaults is NIL - App Group not working!")
        }

        // Get app-specific data from shared storage
        var stats = sharedData.loadUsageStats()
        var intention = sharedData.loadAppIntention()

        // Get real app name from iOS (might be nil)
        let displayName = application.localizedDisplayName ?? "Unknown App"
        print("🛡️ SHIELD: Display name = \(displayName)")

        // STRATEGY: Match this Application to a stored token to find the correct key
        var finalKey: String?
        var needsMigration = false
        var oldTokenKey: String?

        print("🛡️ SHIELD: Starting token matching...")
        print("🛡️ SHIELD: Total intentions to check: \(intention.perAppIntentions.count)")

        // First, try to match the application token to stored tokens
        // We need to encode the current application's token and compare
        if let currentAppData = try? JSONEncoder().encode(application.token) {
            print("🛡️ SHIELD: ✅ Successfully encoded current app token (\(currentAppData.count) bytes)")

            // Look through all intentions to find matching token
            var checkedCount = 0
            for (key, appIntention) in intention.perAppIntentions {
                checkedCount += 1
                print("🛡️ SHIELD: Checking intention #\(checkedCount): key='\(key)'")

                if let storedTokenData = appIntention.appTokenData {
                    print("🛡️ SHIELD: - Has stored token (\(storedTokenData.count) bytes)")

                    // Compare the token data
                    if currentAppData == storedTokenData {
                        print("🛡️ SHIELD: ✅✅✅ MATCH FOUND! Key: \(key)")
                        finalKey = key

                        // Check if this is a token-based key that needs migration
                        if key.hasPrefix("app_") && displayName != "Unknown App" {
                            print("🛡️ SHIELD: Token-based key needs migration to '\(displayName)'")
                            oldTokenKey = key
                            needsMigration = true
                        }
                        break
                    } else {
                        print("🛡️ SHIELD: - No match (tokens different)")
                    }
                } else {
                    print("🛡️ SHIELD: - No stored token data")
                }
            }

            if finalKey == nil {
                print("🛡️ SHIELD: ❌ No matching token found after checking \(checkedCount) intentions")
            }
        } else {
            print("🛡️ SHIELD: ❌ Failed to encode current app token")
        }

        // If we still don't have a key, try fallback strategies
        if finalKey == nil {
            print("🛡️ SHIELD: No token match found, trying fallback strategies...")

            // Fallback 1: If there's only one intention, use it
            if intention.perAppIntentions.count == 1, let singleKey = intention.perAppIntentions.keys.first {
                print("🛡️ SHIELD: Using single intention key: \(singleKey)")
                finalKey = singleKey

                // Check if it needs migration
                if singleKey.hasPrefix("app_") && displayName != "Unknown App" {
                    oldTokenKey = singleKey
                    needsMigration = true
                }
            }
            // Fallback 2: Use display name if we have one
            else if displayName != "Unknown App" {
                print("🛡️ SHIELD: Using display name: \(displayName)")
                finalKey = displayName
            }
        }

        // Perform migration if needed (after ALL key resolution including fallbacks)
        if needsMigration, let oldKey = oldTokenKey {
            // Migrate intention data
            if let intentionData = intention.perAppIntentions[oldKey] {
                intention.perAppIntentions[displayName] = intentionData
                intention.perAppIntentions.removeValue(forKey: oldKey)
                sharedData.saveAppIntention(intention)
                print("🛡️ SHIELD: ✅ Migrated intention from '\(oldKey)' to '\(displayName)'")
            }

            // Migrate stats data - check BOTH old key and look for any breakthroughs
            // that might exist under either key
            let oldBreakthroughs = stats.breakthroughsByApp[oldKey] ?? 0
            let existingBreakthroughs = stats.breakthroughsByApp[displayName] ?? 0

            // Keep the higher count (in case data exists under both keys)
            if oldBreakthroughs > 0 || existingBreakthroughs > 0 {
                stats.breakthroughsByApp[displayName] = max(oldBreakthroughs, existingBreakthroughs)
                stats.breakthroughsByApp.removeValue(forKey: oldKey)
            }

            if let streak = stats.currentStreakByApp[oldKey] {
                stats.currentStreakByApp[displayName] = streak
                stats.currentStreakByApp.removeValue(forKey: oldKey)
            }

            if let longestStreak = stats.longestStreakByApp[oldKey] {
                stats.longestStreakByApp[displayName] = longestStreak
                stats.longestStreakByApp.removeValue(forKey: oldKey)
            }

            if stats.unlockedApps.contains(oldKey) {
                stats.unlockedApps.remove(oldKey)
                stats.unlockedApps.insert(displayName)
            }

            if let expiry = stats.unlockExpiryByApp[oldKey] {
                stats.unlockExpiryByApp[displayName] = expiry
                stats.unlockExpiryByApp.removeValue(forKey: oldKey)
            }

            sharedData.saveUsageStats(stats)
            print("🛡️ SHIELD: ✅ Migrated stats from '\(oldKey)' to '\(displayName)'")

            // Save mapping: displayName -> storeKey (keep the oldKey as store identifier)
            sharedData.updateStoreKeyMapping(displayName: displayName, storeKey: oldKey)
            print("🛡️ SHIELD: ✅ Saved store mapping: '\(displayName)' -> '\(oldKey)'")

            finalKey = displayName
        }

        let appKey = finalKey ?? displayName
        print("🛡️ SHIELD: ========== FINAL KEY: \(appKey) ==========")

        // IMPORTANT: Before proceeding, ensure ALL breakthrough data for this app uses the same key
        // This fixes the key mismatch issue where breakthroughs might be saved under old token keys
        if let currentAppData = try? JSONEncoder().encode(application.token) {
            print("🛡️ SHIELD: Checking for breakthrough data under other keys...")
            var found = false
            for (key, otherIntention) in intention.perAppIntentions {
                if let tokenData = otherIntention.appTokenData, tokenData == currentAppData, key != appKey {
                    // This is the same app but under a different key - migrate its breakthroughs
                    if let count = stats.breakthroughsByApp[key] {
                        print("🛡️ SHIELD: ⚠️ Found breakthroughs under old key '\(key)': \(count), migrating to '\(appKey)'")
                        let existing = stats.breakthroughsByApp[appKey] ?? 0
                        stats.breakthroughsByApp[appKey] = max(existing, count) // Keep the higher count
                        stats.breakthroughsByApp.removeValue(forKey: key)
                        found = true
                    }
                }
            }
            if found {
                sharedData.saveUsageStats(stats)
                print("🛡️ SHIELD: ✅ Breakthrough data migrated and saved")
            }
        }

        // Determine block type: "intention" (app has per-app intention) or "schedule" (scheduled session block)
        // Check if THIS SPECIFIC APP is in an active schedule's blocked list
        let isAppInSchedule = isAppInActiveSchedule(application: application)
        let hasAppIntention = intention.perAppIntentions[appKey] != nil
        let timeWasterApps = sharedData.loadTimeWasterApps()
        let blockType: String
        if isAppInSchedule && hasAppIntention {
            // App has both — schedule takes priority while active
            blockType = "schedule"
        } else if isAppInSchedule {
            // App is blocked by schedule only
            blockType = "schedule"
        } else if hasAppIntention {
            // App has intention only
            blockType = "intention"
        } else {
            // Fallback — check if any schedule is active (category-based blocking etc.)
            blockType = sharedData.isAnyScheduleActive() ? "schedule" : "intention"
        }

        print("🛡️ SHIELD: Block type determination:")
        //print("🛡️ SHIELD: - Has active schedule: \(hasActiveSchedule)")
        print("🛡️ SHIELD: - Has app intention: \(hasAppIntention)")
        print("🛡️ SHIELD: - In time waster apps: \(timeWasterApps.contains(appKey))")
        print("🛡️ SHIELD: - Final block type: \(blockType)")

        // IMPORTANT: Reload stats from App Groups to get the latest data AFTER migration
        // Force synchronize again to pick up any changes from main app
        sharedData.sharedDefaults?.synchronize()
        stats = sharedData.loadUsageStats()
        print("🛡️ SHIELD: Reloaded fresh stats from App Groups after migration")

        // NOTE: We do NOT write intervention state here.
        // ShieldConfigurationExtension is READ-ONLY for intervention state.
        // ShieldActionExtension writes pendingApp, interventionActive, and blockType
        // when the user actually taps "Continue".

        // Get usage data using the app key
        // Try direct lookup first, then fallback via storeKeyMapping for key mismatch cases
        var appIntention = intention.perAppIntentions[appKey]
        if appIntention == nil && !appKey.hasPrefix("app_") {
            // Display name key didn't match — try finding via storeKeyMapping (token key)
            let mapping = sharedData.loadStoreKeyMapping()
            if let tokenKey = mapping[appKey], let tokenIntention = intention.perAppIntentions[tokenKey] {
                print("🛡️ SHIELD: Found intention via storeKeyMapping: '\(appKey)' -> '\(tokenKey)'")
                appIntention = tokenIntention
                // Migrate intention to display name key
                intention.perAppIntentions[appKey] = tokenIntention
                intention.perAppIntentions.removeValue(forKey: tokenKey)
                sharedData.saveAppIntention(intention)
                print("🛡️ SHIELD: ✅ Migrated intention from '\(tokenKey)' to '\(appKey)'")
            }
        }
        if appIntention == nil && appKey.hasPrefix("app_") {
            // Token key didn't match — try finding via reverse storeKeyMapping (display name)
            let mapping = sharedData.loadStoreKeyMapping()
            for (displayName, tokenKey) in mapping {
                if tokenKey == appKey, let namedIntention = intention.perAppIntentions[displayName] {
                    print("🛡️ SHIELD: Found intention via reverse storeKeyMapping: '\(appKey)' -> '\(displayName)'")
                    appIntention = namedIntention
                    break
                }
            }
        }
        // Last resort: if only one intention exists, use it
        if appIntention == nil && intention.perAppIntentions.count == 1,
           let singleIntention = intention.perAppIntentions.values.first {
            print("🛡️ SHIELD: Using single intention as fallback for '\(appKey)'")
            appIntention = singleIntention
        }
        let limit = appIntention?.timesPerDay ?? intention.timesPerDay

        // Get breakthrough count - check under display name AND any token keys that match this app
        var finalBreakthroughs = stats.breakthroughsByApp[appKey] ?? 0

        // If no breakthroughs found under the display name, check for token-keyed data
        if finalBreakthroughs == 0 && !appKey.hasPrefix("app_") {
            // Look for breakthroughs under any token key that maps to this display name
            let mapping = sharedData.loadStoreKeyMapping()
            if let tokenKey = mapping[appKey], let tokenBreakthroughs = stats.breakthroughsByApp[tokenKey], tokenBreakthroughs > 0 {
                print("🛡️ SHIELD: Found breakthroughs under token key '\(tokenKey)': \(tokenBreakthroughs), migrating to '\(appKey)'")
                finalBreakthroughs = tokenBreakthroughs
                // Migrate the data while we're here
                stats.breakthroughsByApp[appKey] = tokenBreakthroughs
                stats.breakthroughsByApp.removeValue(forKey: tokenKey)
                sharedData.saveUsageStats(stats)
            }
        }

        print("🛡️ SHIELD: ========== BREAKTHROUGH LOOKUP ==========")
        print("🛡️ SHIELD: App key: '\(appKey)'")
        print("🛡️ SHIELD: Breakthroughs: \(finalBreakthroughs)/\(limit)")
        print("🛡️ SHIELD: All breakthroughsByApp keys: \(Array(stats.breakthroughsByApp.keys))")
        print("🛡️ SHIELD: Full breakthroughsByApp: \(stats.breakthroughsByApp)")
        print("🛡️ SHIELD: ==========================================")

        // Check if app is unlocked — also verify the unlock hasn't expired (stale data guard)
        var isUnlocked = stats.unlockedApps.contains(appKey)
        if isUnlocked {
            if let expiry = stats.unlockExpiryByApp[appKey], expiry < Date() {
                // Unlock has expired but wasn't cleaned up — treat as not unlocked
                print("🛡️ SHIELD: ⚠️ Stale unlock detected for \(appKey) — expiry \(expiry) has passed, treating as locked")
                isUnlocked = false
            } else if stats.unlockExpiryByApp[appKey] == nil {
                // No expiry record at all — likely stale data from key mismatch
                print("🛡️ SHIELD: ⚠️ No expiry found for unlocked app \(appKey) — treating as locked (stale data)")
                isUnlocked = false
            }
        }

        // Check if user already pressed Continue (intervention is active)
        let isInterventionActive = sharedData.loadInterventionActive()
        print("🛡️ SHIELD: isInterventionActive = \(isInterventionActive)")

        // Create custom shield configuration
        let config = ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0), // Light purple-gray
            icon: createBeYouIcon(),
            title: createShieldTitle(appName: displayName, breakthroughs: finalBreakthroughs, limit: limit, isUnlocked: isUnlocked, blockType: blockType),
            subtitle: createShieldSubtitle(appName: displayName, breakthroughs: finalBreakthroughs, limit: limit, isUnlocked: isUnlocked, isInterventionActive: isInterventionActive, blockType: blockType),
            primaryButtonLabel: createPrimaryButtonLabel(isUnlocked: isUnlocked, isInterventionActive: isInterventionActive, blockType: blockType),
            primaryButtonBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.8, alpha: 1.0), // Purple
            secondaryButtonLabel: createSecondaryButtonLabel(blockType: blockType)
        )

        return config
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Use same configuration for category-based blocking
        return configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Custom shield for web domains
        let config = ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0),
            icon: createBeYouIcon(),
            title: ShieldConfiguration.Label(text: "Website Blocked", color: .label),
            subtitle: ShieldConfiguration.Label(text: "This website is part of your mindful screen time goals.", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Open BeYou", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.4, green: 0.3, blue: 0.8, alpha: 1.0)
        )

        return config
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Use same configuration for category-based web blocking
        return configuration(shielding: webDomain)
    }

    // MARK: - Per-App Schedule Check

    /// Check if this specific app is in any active schedule's blocked list
    private func isAppInActiveSchedule(application: Application) -> Bool {
        guard let currentTokenData = try? JSONEncoder().encode(application.token) else {
            return false
        }
        let activeTokens = sharedData.loadActiveScheduleTokenData()
        return activeTokens.contains(currentTokenData)
    }

    // MARK: - Helper Methods

    private func createBeYouIcon() -> UIImage? {
        // Try to load from this extension's bundle
        if let image = UIImage(named: "be-you-icon") {
            return image
        }

        // Try loading from the main app bundle via App Group container
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.odudu.BeYou") {
            let iconPath = containerURL.appendingPathComponent("be-you-icon.png")
            if let image = UIImage(contentsOfFile: iconPath.path) {
                return image
            }
        }

        // Fallback: create a simple placeholder icon
        return createPlaceholderIcon()
    }

    private func createPlaceholderIcon() -> UIImage? {
        // Create a simple circular icon as fallback
        let size = CGSize(width: 80, height: 80)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Purple circle background
            UIColor(red: 0.4, green: 0.3, blue: 0.8, alpha: 1.0).setFill()
            let circle = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            circle.fill()

            // White "B" letter
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let string = "B"
            let textSize = string.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            string.draw(in: textRect, withAttributes: attrs)
        }
    }

    private func createShieldTitle(appName: String, breakthroughs: Int, limit: Int, isUnlocked: Bool, blockType: String) -> ShieldConfiguration.Label {
        let titleText: String

        if isUnlocked {
            titleText = "Session Active"
        } else if blockType == "schedule" {
            let showInstructions = sharedData.loadScheduleShowInstructions()
            titleText = showInstructions ? "How to Unblock" : "Stay Focused"
        } else if breakthroughs >= limit {
            titleText = "Daily Limit Reached"
        } else {
            // Intention block — check if intervention is active (State 2)
            let isInterventionActive = sharedData.loadInterventionActive()
            titleText = isInterventionActive ? "Almost There!" : "Stay Mindful"
        }

        return ShieldConfiguration.Label(text: titleText, color: .label)
    }

    private func createShieldSubtitle(appName: String, breakthroughs: Int, limit: Int, isUnlocked: Bool, isInterventionActive: Bool, blockType: String) -> ShieldConfiguration.Label? {
        let subtitleText: String

        if isUnlocked {
            subtitleText = "You're in a session. Use your time wisely."
        } else if blockType == "schedule" {
            let showInstructions = sharedData.loadScheduleShowInstructions()
            if showInstructions {
                subtitleText = "To unblock this app:\n\n1. Open the BeYou app\n2. On the Home tab, find your active blocking session\n3. Tap the red stop button beside it\n4. Tap OK to confirm\n\nThe block will be removed immediately."
            } else {
                subtitleText = "This is your scheduled disconnect time.\n\nStay focused and make the most of this moment."
            }
        } else if breakthroughs >= limit {
            subtitleText = "You've opened this app \(breakthroughs)/\(limit) times today.\n\nDon't you think that's enough scrolling for today?"
        } else if isInterventionActive {
            // STATE 2: User pressed Continue — waiting for notification
            subtitleText = "Tap the notification or open the BeYou app to open this app."
        } else {
            // STATE 1: First time seeing this shield
            subtitleText = "Are you sure you want to open \(appName)?\n\nTap Continue to start your mindful unlock."
        }

        return ShieldConfiguration.Label(text: subtitleText, color: .secondaryLabel)
    }

    private func createPrimaryButtonLabel(isUnlocked: Bool, isInterventionActive: Bool, blockType: String) -> ShieldConfiguration.Label? {
        let buttonText: String

        if isUnlocked {
            buttonText = "Close"
        } else if blockType == "schedule" {
            let showInstructions = sharedData.loadScheduleShowInstructions()
            buttonText = showInstructions ? "Close" : "Be Focused"
        } else if isInterventionActive {
            // STATE 2: User already pressed Continue — offer to resend
            buttonText = "Resend Notification"
        } else {
            // STATE 1: First time seeing this shield
            buttonText = "Continue"
        }

        return ShieldConfiguration.Label(text: buttonText, color: .white)
    }

    private func createSecondaryButtonLabel(blockType: String) -> ShieldConfiguration.Label? {
        if blockType == "schedule" {
            let showInstructions = sharedData.loadScheduleShowInstructions()
            if showInstructions {
                return nil
            }
            return ShieldConfiguration.Label(text: "Open?", color: .label)
        }

        // Intention block
        let isInterventionActive = sharedData.loadInterventionActive()
        if isInterventionActive {
            // STATE 2: Show "Nevermind" to let user cancel after pressing Continue
            return ShieldConfiguration.Label(text: "Nevermind", color: .label)
        }

        // STATE 1: Show "Nevermind" to dismiss without continuing
        return ShieldConfiguration.Label(text: "Nevermind", color: .label)
    }
}

// MARK: - SharedDataManager (Extension Version)

class SharedDataManager {
    static let shared = SharedDataManager()
    private let appGroupIdentifier = "group.com.odudu.BeYou"

    var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

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

    func loadUsageStats() -> AppUsageStats {
        var stats = AppUsageStats()

        stats.breakthroughsToday = sharedDefaults?.integer(forKey: "breakthroughsToday") ?? 0

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

    // MARK: - Pending App to Unlock

    func savePendingAppToUnlock(_ appName: String?) {
        print("💾 SHIELD-SHARED: Saving pending app: \(appName ?? "nil")")
        sharedDefaults?.set(appName, forKey: "pendingAppToUnlock")
        let success = sharedDefaults?.synchronize() ?? false
        print("💾 SHIELD-SHARED: Save synchronize result: \(success)")
    }

    func saveInterventionActive(_ isActive: Bool) {
        print("💾 SHIELD-SHARED: Saving intervention active: \(isActive)")
        sharedDefaults?.set(isActive, forKey: "isInterventionActive")
        let success = sharedDefaults?.synchronize() ?? false
        print("💾 SHIELD-SHARED: Save synchronize result: \(success)")
    }

    func loadPendingAppToUnlock() -> String? {
        let appName = sharedDefaults?.string(forKey: "pendingAppToUnlock")
        print("💾 SHIELD-SHARED: Loading pending app: \(appName ?? "nil")")
        return appName
    }

    func loadInterventionActive() -> Bool {
        let isActive = sharedDefaults?.bool(forKey: "isInterventionActive") ?? false
        print("💾 SHIELD-SHARED: Loading intervention active: \(isActive)")
        return isActive
    }

    // MARK: - Time Waster Apps

    func loadTimeWasterApps() -> [String] {
        if let data = sharedDefaults?.data(forKey: "timeWasterApps"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            print("💾 SHIELD-SHARED: Loaded \(decoded.count) time waster apps")
            return decoded
        }
        print("💾 SHIELD-SHARED: No time waster apps found")
        return []
    }

    // MARK: - Block Type

    func saveBlockType(_ type: String) {
        print("💾 SHIELD-SHARED: Saving block type: \(type)")
        sharedDefaults?.set(type, forKey: "currentBlockType")
        sharedDefaults?.synchronize()
    }

    func loadBlockType() -> String {
        let type = sharedDefaults?.string(forKey: "currentBlockType") ?? "intention"
        print("💾 SHIELD-SHARED: Loading block type: \(type)")
        return type
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

    // MARK: - Save Methods

    func saveAppIntention(_ intention: AppIntention) {
        print("💾 SHIELD-SHARED: Saving app intention")
        sharedDefaults?.set(intention.timesPerDay, forKey: "intentionTimesPerDay")
        sharedDefaults?.set(intention.minutesPerSession, forKey: "intentionMinutesPerSession")

        if let encoded = try? JSONEncoder().encode(intention.perAppIntentions) {
            sharedDefaults?.set(encoded, forKey: "perAppIntentions")
        }

        let success = sharedDefaults?.synchronize() ?? false
        print("💾 SHIELD-SHARED: Save intention synchronize result: \(success)")
    }

    func saveUsageStats(_ stats: AppUsageStats) {
        print("💾 SHIELD-SHARED: Saving usage stats")
        sharedDefaults?.set(stats.breakthroughsToday, forKey: "breakthroughsToday")

        if let encoded = try? JSONEncoder().encode(stats.breakthroughsByApp) {
            sharedDefaults?.set(encoded, forKey: "breakthroughsByApp")
        }

        if let encoded = try? JSONEncoder().encode(stats.currentStreakByApp) {
            sharedDefaults?.set(encoded, forKey: "currentStreakByApp")
        }

        if let encoded = try? JSONEncoder().encode(stats.longestStreakByApp) {
            sharedDefaults?.set(encoded, forKey: "longestStreakByApp")
        }

        if let encoded = try? JSONEncoder().encode(Array(stats.unlockedApps)) {
            sharedDefaults?.set(encoded, forKey: "unlockedApps")
        }

        if let encoded = try? JSONEncoder().encode(stats.unlockExpiryByApp) {
            sharedDefaults?.set(encoded, forKey: "unlockExpiryByApp")
        }

        let success = sharedDefaults?.synchronize() ?? false
        print("💾 SHIELD-SHARED: Save stats synchronize result: \(success)")
    }

    // MARK: - Store Key Mapping

    func updateStoreKeyMapping(displayName: String, storeKey: String) {
        var mapping = loadStoreKeyMapping()
        mapping[displayName] = storeKey

        if let encoded = try? JSONEncoder().encode(mapping) {
            sharedDefaults?.set(encoded, forKey: "storeKeyMapping")
        }

        let success = sharedDefaults?.synchronize() ?? false
        print("💾 SHIELD-SHARED: Updated store mapping \(displayName) -> \(storeKey), sync: \(success)")
    }

    func loadStoreKeyMapping() -> [String: String] {
        if let data = sharedDefaults?.data(forKey: "storeKeyMapping"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            return decoded
        }
        return [:]
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

struct AppUsageStats {
    var breakthroughsToday: Int = 0
    var breakthroughsByApp: [String: Int] = [:]
    var currentStreakByApp: [String: Int] = [:]
    var longestStreakByApp: [String: Int] = [:]
    var unlockedApps: Set<String> = []
    var unlockExpiryByApp: [String: Date] = [:]
}
