# Extension Templates for Manual Setup

This file contains the complete code for the DeviceActivity Monitor and ShieldConfiguration extensions. Copy these into your Xcode extension targets after creating them.

## DeviceActivityMonitorExtension.swift

**Target:** BeYouDeviceActivityMonitor

```swift
import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications

@available(iOS 16.0, *)
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    let store = ManagedSettingsStore()

    override nonisolated func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // This is called when the monitoring interval starts
        // For example, when "Before Bed" schedule begins (9 PM)

        // Apply shields based on schedule type
        if activity == .beforeBedSchedule {
            applyBeforeBedBlocking()
            sendDisconnectStartedNotification(type: "Before Bed")
        } else if activity == .morningSchedule {
            applyMorningBlocking()
            sendDisconnectStartedNotification(type: "Morning")
        } else if activity == .workSchedule {
            applyWorkBlocking()
            sendDisconnectStartedNotification(type: "At Work")
        }
    }

    override nonisolated func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // This is called when the monitoring interval ends
        // For example, when "Before Bed" schedule ends (7 AM)

        // Remove time-based shields
        if activity == .beforeBedSchedule || activity == .morningSchedule || activity == .workSchedule {
            removeScheduleBlocking()
        }
    }

    override nonisolated func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        // This is called when an app usage threshold is reached
        // For example, when user has opened Instagram 10 times today

        // Apply blocking when threshold reached
        applyIntentionBlocking()
    }

    override nonisolated func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)

        // Send notification 10 min before schedule starts
        let content = UNMutableNotificationContent()

        switch activity {
        case .morningSchedule:
            content.title = "Morning Focus Starting Soon"
            content.body = "Your morning disconnect time starts in 10 minutes"
        case .beforeBedSchedule:
            content.title = "Bedtime Focus Starting Soon"
            content.body = "Your bedtime disconnect time starts in 10 minutes"
        case .workSchedule:
            content.title = "Work Focus Starting Soon"
            content.body = "Your work disconnect time starts in 10 minutes"
        default:
            return
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "interval_start_warning_\(activity)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    override nonisolated func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)

        // Send notification before schedule ends
        let content = UNMutableNotificationContent()

        switch activity {
        case .morningSchedule:
            content.title = "Morning Focus Ending Soon"
            content.body = "Your morning focus ends in 5 minutes"
        case .beforeBedSchedule:
            content.title = "Bedtime Focus Ending Soon"
            content.body = "Your bedtime focus ends in 5 minutes"
        case .workSchedule:
            content.title = "Work Focus Ending Soon"
            content.body = "Your work focus ends in 5 minutes"
        default:
            return
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "interval_end_warning_\(activity)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    override nonisolated func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)

        // Send notification when approaching limit
        let stats = loadUsageStats()
        let intention = loadAppIntention()

        let content = UNMutableNotificationContent()
        content.title = "Approaching Your Limit"
        content.body = "You've opened your apps \(stats.breakthroughsToday)/\(intention.timesPerDay) times today"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "threshold_warning",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Blocking Logic

    private nonisolated func applyBeforeBedBlocking() {
        // Block all selected apps during "Before Bed" schedule
        let selection = loadAppSelection()
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
    }

    private nonisolated func applyMorningBlocking() {
        // Block all selected apps during "Morning" schedule
        let selection = loadAppSelection()
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
    }

    private nonisolated func applyWorkBlocking() {
        // Block all selected apps during "At Work" schedule
        let selection = loadAppSelection()
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
    }

    private nonisolated func applyIntentionBlocking() {
        // Block apps when user exceeds daily intention
        let selection = loadAppSelection()
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
    }

    private nonisolated func removeScheduleBlocking() {
        // Check if app is still blocked by intention limit
        let stats = loadUsageStats()
        let intention = loadAppIntention()

        if stats.breakthroughsToday >= intention.timesPerDay {
            // Keep blocking - they're over their daily limit
            return
        }

        // Remove shields
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    // MARK: - Data Loading (from App Group)

    private nonisolated func loadAppSelection() -> FamilyActivitySelection {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.beyou.app") else {
            return FamilyActivitySelection()
        }

        // Load the serialized app selection
        // TODO: Implement proper serialization/deserialization
        return FamilyActivitySelection()
    }

    private nonisolated func loadUsageStats() -> AppUsageStats {
        guard let _ = UserDefaults(suiteName: "group.com.beyou.app") else {
            return AppUsageStats()
        }

        let sharedDefaults = UserDefaults(suiteName: "group.com.beyou.app")!
        let breakthroughs = sharedDefaults.integer(forKey: "breakthroughsToday")
        var stats = AppUsageStats()
        stats.breakthroughsToday = breakthroughs
        return stats
    }

    private nonisolated func loadAppIntention() -> AppIntention {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.beyou.app") else {
            return AppIntention()
        }

        let timesPerDay = sharedDefaults.integer(forKey: "intentionTimesPerDay")
        let minutesPerSession = sharedDefaults.integer(forKey: "intentionMinutesPerSession")

        var intention = AppIntention()
        if timesPerDay > 0 {
            intention.timesPerDay = timesPerDay
        }
        if minutesPerSession > 0 {
            intention.minutesPerSession = minutesPerSession
        }
        return intention
    }

    // MARK: - Notification Helpers

    private nonisolated func sendDisconnectStartedNotification(type: String) {
        let content = UNMutableNotificationContent()

        switch type {
        case "Morning":
            content.title = "🌅 Morning Focus Active"
            content.body = "Your morning disconnect time has started"
        case "Before Bed":
            content.title = "🌙 Bedtime Focus Active"
            content.body = "Time to wind down for the night"
        case "At Work":
            content.title = "💼 Work Focus Active"
            content.body = "Stay productive during work hours"
        default:
            return
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "disconnect_started_\(type.lowercased().replacingOccurrences(of: " ", with: "_"))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - DeviceActivity Names

@available(iOS 16.0, *)
extension DeviceActivityName {
    static nonisolated(unsafe) let beforeBedSchedule = DeviceActivityName("beforeBedSchedule")
    static nonisolated(unsafe) let morningSchedule = DeviceActivityName("morningSchedule")
    static nonisolated(unsafe) let workSchedule = DeviceActivityName("workSchedule")
    static nonisolated(unsafe) let dailyIntention = DeviceActivityName("dailyIntention")
}
```

---

## ShieldConfigurationExtension.swift

**Target:** BeYouShieldConfiguration

```swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

@available(iOS 16.0, *)
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override nonisolated func configuration(shielding application: Application) -> ShieldConfiguration {
        // Customize the shield for a specific application

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor.black,
            icon: loadBeYouIcon(),
            title: ShieldConfiguration.Label(
                text: "Take a mindful break",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Open BeYou to continue",
                color: .white.withAlphaComponent(0.8)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open BeYou",
                color: UIColor(red: 0.357, green: 0.624, blue: 1.0, alpha: 1.0) // #5B9FFF
            ),
            primaryButtonBackgroundColor: nil,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Nevermind",
                color: .white.withAlphaComponent(0.6)
            )
        )
    }

    override nonisolated func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield for applications in a specific category

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor.black,
            icon: loadBeYouIcon(),
            title: ShieldConfiguration.Label(
                text: "Category Blocked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This category is blocked during your focus time",
                color: .white.withAlphaComponent(0.8)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open BeYou",
                color: UIColor(red: 0.357, green: 0.624, blue: 1.0, alpha: 1.0)
            )
        )
    }

    override nonisolated func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Customize the shield for a specific web domain

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor.black,
            icon: loadBeYouIcon(),
            title: ShieldConfiguration.Label(
                text: "Website Blocked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This website is blocked during your focus time",
                color: .white.withAlphaComponent(0.8)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open BeYou",
                color: UIColor(red: 0.357, green: 0.624, blue: 1.0, alpha: 1.0)
            )
        )
    }

    override nonisolated func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield for web domains in a specific category

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor.black,
            icon: loadBeYouIcon(),
            title: ShieldConfiguration.Label(
                text: "Website Category Blocked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This category is blocked during your focus time",
                color: .white.withAlphaComponent(0.8)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open BeYou",
                color: UIColor(red: 0.357, green: 0.624, blue: 1.0, alpha: 1.0)
            )
        )
    }

    // MARK: - Helper

    private nonisolated func loadBeYouIcon() -> UIImage? {
        // Try to load the BeYou app icon
        // Note: Extension bundles can't access main app assets directly
        // You may need to include the icon in the extension's assets

        if let image = UIImage(named: "be-you-icon") {
            return image
        }

        // Fallback to system icon
        return UIImage(systemName: "app.fill")
    }
}
```

---

## Usage Instructions

### Step 1: Create Extension Targets in Xcode

1. **DeviceActivity Monitor Extension:**
   - File → New → Target
   - Select "Device Activity Monitor Extension"
   - Name: `BeYouDeviceActivityMonitor`
   - Copy the code above into the generated file

2. **ShieldConfiguration Extension:**
   - File → New → Target
   - Select "Shield Configuration Extension"
   - Name: `BeYouShieldConfiguration`
   - Copy the code above into the generated file

### Step 2: Configure Both Extensions

For each extension target:

1. **Enable App Groups:**
   - Select extension target
   - Signing & Capabilities
   - + Capability → App Groups
   - Add: `group.com.beyou.app`

2. **Set Deployment Target:**
   - iOS 16.0 or later

3. **Link Required Frameworks:**
   - Build Phases → Link Binary With Libraries
   - DeviceActivity.framework
   - ManagedSettings.framework
   - FamilyControls.framework
   - (ShieldConfiguration also needs ManagedSettingsUI.framework)

### Step 3: Build and Test

1. Build the project (Cmd+B)
2. Deploy to physical device (extensions require real device)
3. Test the blocking functionality

See PHASE1_SETUP_GUIDE.md for complete setup instructions.
