import SwiftUI
import RevenueCat
import FamilyControls
import SuperwallKit

@available(iOS 16.0, *)
@main
struct BeYouSwiftApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var screenTimeManager = ScreenTimeManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Set up notification delegate for handling taps
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Configure RevenueCat first (needed before syncing subscription status)
        SubscriptionManager.shared.configure()

        // Configure Superwall + sync subscription status from RevenueCat
        SuperwallService.configure()

        // Configure Mixpanel analytics
        AnalyticsManager.shared.configure()

        // Configure TikTok Ads SDK
        TikTokManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(screenTimeManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                // Refresh entitlements on foreground so the reactive subscription gate reflects a
                // lapse/renewal promptly. The gate itself (ContentView) decides whether to show
                // the paywall — there is no separate paywall trigger here anymore.
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        Task { await SubscriptionManager.shared.refreshEntitlements() }
                    }
                }
                .task {
                    // Track app open
                    AnalyticsManager.shared.trackAppOpened()
                    TikTokManager.shared.trackAppOpen()

                    // Re-authorize FamilyControls on every launch
                    // Silent if already authorized; re-prompts only if lost (e.g., after update)
                    await reauthorizeFamilyControls()

                    // Check daily reset
                    appState.checkDailyReset()

                    // Refresh entitlements so the reactive subscription gate has current status.
                    await SubscriptionManager.shared.refreshEntitlements()

                    // Sync remote affirmations from Supabase (daily, silent fail if offline)
                    await AffirmationService.shared.syncRemoteAffirmations()

                    // Schedule recurring notifications (only works if permission already granted)
                    scheduleRecurringNotifications()

                    // Copy app icon to shared container so Shield extension can use it
                    copyIconToSharedContainer()
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        print("🔗 DEEP LINK: Received URL: \(url)")
        print("🔗 DEEP LINK: Scheme: \(url.scheme ?? "nil")")
        print("🔗 DEEP LINK: Host: \(url.host ?? "nil")")
        print("🔗 DEEP LINK: Path: \(url.path)")

        guard url.scheme == "beyou" else {
            print("🔗 DEEP LINK: ❌ Unknown scheme")
            return
        }

        switch url.host {
        case "test":
            print("🔗 DEEP LINK: ✅ TEST URL SCHEME WORKS!")
            print("🔗 DEEP LINK: This means we can open BeYou directly from ShieldActionExtension!")

        case "intentioncheck", "intervention":
            print("🔗 DEEP LINK: ✅ INTERVENTION URL - Opening intervention sheet!")

            // Load pending app from shared storage
            let sharedData = SharedDataManager.shared
            let appName = sharedData.loadPendingAppToUnlock() ?? "this app"
            print("🔗 DEEP LINK: Pending app: \(appName)")

            // Set intervention active
            appState.isInterventionActive = true
            appState.pendingAppToUnlock = appName

            // Post notification to show sheet
            NotificationCenter.default.post(name: NSNotification.Name("ShowInterventionSheet"), object: nil)
            print("🔗 DEEP LINK: Posted ShowInterventionSheet notification")

        default:
            print("🔗 DEEP LINK: ❌ Unknown host: \(url.host ?? "nil")")
        }
    }

    private func reauthorizeFamilyControls() async {
        // Screen Time access is only needed for App Block. Only (re)authorize when:
        //  - App Block is enabled (the user opted in), or
        //  - access was already granted (silent re-confirm — this never shows a prompt).
        // This guarantees a first-time user is never prompted for Screen Time unless they
        // actually turn on App Block.
        let alreadyAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        guard AppBlockStore.isEnabled || alreadyAuthorized else {
            print("📱 APP: Skipping FamilyControls re-auth (App Block off and not yet authorized)")
            return
        }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            // Refresh the cached status so blockApp/reapplyAllBlocks see the real value
            screenTimeManager.updateAuthorizationStatus()
            print("📱 APP: FamilyControls authorization confirmed, status: \(screenTimeManager.authorizationStatus)")
        } catch {
            screenTimeManager.updateAuthorizationStatus()
            print("❌ APP: FamilyControls authorization failed: \(error), status: \(screenTimeManager.authorizationStatus)")
        }
    }

    private func copyIconToSharedContainer() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.odudu.BeYou") else { return }
        let destPath = containerURL.appendingPathComponent("be-you-icon.png")
        // Only copy if not already there
        guard !FileManager.default.fileExists(atPath: destPath.path) else { return }
        if let image = UIImage(named: "be-you-icon"),
           let data = image.pngData() {
            try? data.write(to: destPath)
            print("📱 APP: Copied app icon to shared container")
        }
    }

    private func scheduleRecurringNotifications() {
        // Cancel the old "Daily Reset / app limits reset" notification (no longer used) and
        // remove any copy already scheduled on the device.
        NotificationManager.shared.cancelNotification(identifier: .midnightReset)

        // Schedule daily reminder
        NotificationManager.shared.scheduleDailyReminder()

        // 6pm "here are tomorrow's alarms" reminder
        NotificationManager.shared.refreshTomorrowAlarmsReminder(alarms: AlarmScheduler.loadAlarms())

        // Schedule disconnect warnings if user has set them
        let disconnectSchedule = appState.onboardingData.disconnectSchedule
        if let type = disconnectSchedule.type,
           let startTime = disconnectSchedule.startTime {
            NotificationManager.shared.scheduleDisconnectWarning(type: type, startTime: startTime)
        }

        // Reschedule affirmation notifications daily (refreshes affirmation content each day)
        NotificationManager.shared.rescheduleAffirmationsIfNeeded(onboardingData: appState.onboardingData)
    }
}

// MARK: - App Delegate

@available(iOS 16.0, *)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register for remote notifications (APNs)
        application.registerForRemoteNotifications()
        print("📱 APP DELEGATE: Registered for remote notifications")

        // Set up Darwin notification listener
        setupDarwinNotificationListener()

        return true
    }

    // MARK: - Remote Notification Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert device token to string
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 APP DELEGATE: Got APNs device token: \(tokenString)")

        // Save to App Groups so ShieldAction extension can access it
        let sharedData = SharedDataManager.shared
        sharedData.saveDeviceToken(tokenString)

        print("📱 APP DELEGATE: Saved device token to App Groups")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APP DELEGATE: Failed to register for remote notifications: \(error)")
    }

    // MARK: - Darwin Notification Listener

    /// Sets up listener for Darwin notifications from ShieldAction extension
    private func setupDarwinNotificationListener() {
        let notificationName = "com.odudu.BeYou.unlockRequest" as CFString
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        // Create observer
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())

        CFNotificationCenterAddObserver(
            center,
            observer,
            { (center, observer, name, object, userInfo) in
                print("🔔 DARWIN: Received unlock request notification!")

                // Call Supabase Edge Function to send push notification
                DispatchQueue.main.async {
                    Task {
                        await DarwinNotificationHandler.shared.handleUnlockRequest()
                    }
                }
            },
            notificationName,
            nil,
            .deliverImmediately
        )

        print("📱 APP DELEGATE: Darwin notification listener set up for: \(notificationName)")
    }
}

// MARK: - Darwin Notification Handler

@available(iOS 16.0, *)
class DarwinNotificationHandler {
    static let shared = DarwinNotificationHandler()
    private let sharedData = SharedDataManager.shared

    private init() {}

    @MainActor
    func handleUnlockRequest() async {
        print("🎯 DARWIN HANDLER: Processing unlock request...")

        // Load intervention data from App Groups
        let rawAppName = sharedData.loadPendingAppToUnlock() ?? "this app"

        // Resolve token-based key to display name
        let appName = resolveDisplayName(for: rawAppName)
        print("🎯 DARWIN HANDLER: Raw app name = \(rawAppName)")
        print("🎯 DARWIN HANDLER: Resolved app name = \(appName)")

        // Only update shared storage if we resolved to a REAL display name.
        // Never overwrite the token key with a generic fallback like "the app" —
        // InterventionSheet needs the raw token key for unlock and breakthrough matching.
        if appName != rawAppName && appName != "the app" {
            sharedData.savePendingAppToUnlock(appName)
            print("🎯 DARWIN HANDLER: Updated pending app to display name: \(appName)")
        } else {
            print("🎯 DARWIN HANDLER: Keeping raw key in storage for functional matching")
        }

        // Directly show intervention sheet if app is in foreground
        // This avoids the round-trip through push notification
        print("🎯 DARWIN HANDLER: Posting ShowInterventionSheet notification directly")
        NotificationCenter.default.post(name: NSNotification.Name("ShowInterventionSheet"), object: nil)

        // DO NOT send another push notification here!
        // ShieldActionExtension already sends the push directly via sendPushNotificationDirectly.
        // Sending another push from here was causing double notifications.
        print("🎯 DARWIN HANDLER: Done (push already sent by ShieldActionExtension)")
    }

    /// Public version for use from NotificationDelegate
    func resolveDisplayNamePublic(for rawName: String) -> String {
        return resolveDisplayName(for: rawName)
    }

    /// Resolves a token-based key like "app_123..." to a display name like "Instagram"
    private func resolveDisplayName(for rawName: String) -> String {
        guard rawName.hasPrefix("app_") else { return rawName }

        // Try storeKeyMapping first
        let mapping = sharedData.loadStoreKeyMapping()
        for (displayName, tokenKey) in mapping {
            if tokenKey == rawName { return displayName }
        }

        // Try matching token data in perAppIntentions
        let intention = sharedData.loadAppIntention()
        if let tokenIntention = intention.perAppIntentions[rawName],
           let tokenData = tokenIntention.appTokenData {
            for (key, appIntention) in intention.perAppIntentions {
                if !key.hasPrefix("app_"), let data = appIntention.appTokenData, data == tokenData {
                    return key
                }
            }
        }

        // Never show raw token key to the user — fall back to generic name
        return "the app"
    }

    private func sendPushNotificationViaSupabase(appName: String, deviceToken: String) async {
        print("📤 DARWIN HANDLER: Calling Supabase Edge Function...")

        guard let url = URL(string: "\(Secrets.supabaseURL)/functions/v1/send-unlock-push") else {
            print("❌ DARWIN HANDLER: Invalid Supabase URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "deviceToken": deviceToken,
            "appName": appName,
            "userID": sharedData.loadUserID() ?? ""
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📤 DARWIN HANDLER: Supabase response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 {
                    print("✅ DARWIN HANDLER: Push notification sent successfully!")
                } else {
                    print("❌ DARWIN HANDLER: Failed to send push. Status: \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ DARWIN HANDLER: Response: \(responseString)")
                    }
                }
            }
        } catch {
            print("❌ DARWIN HANDLER: Network error: \(error)")
        }
    }
}

// MARK: - Notification Delegate

@available(iOS 16.0, *)
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    // Handle notification tap when app is in foreground OR background
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 DELEGATE: ============================================")
        print("🔔 DELEGATE: Notification tapped!")
        print("🔔 DELEGATE: Notification ID: \(response.notification.request.identifier)")

        let userInfo = response.notification.request.content.userInfo
        print("🔔 DELEGATE: User info: \(userInfo)")

        // Check if this is an intervention notification
        if let action = userInfo["action"] as? String, action == "openIntervention" {
            print("🔔 DELEGATE: ✅ Intervention notification detected!")

            // Extract app name from notification payload and resolve token names
            var appName = userInfo["appName"] as? String ?? "this app"
            if appName.hasPrefix("app_") {
                // Resolve token-based key to display name
                let resolved = DarwinNotificationHandler.shared.resolveDisplayNamePublic(for: appName)
                if resolved != appName {
                    appName = resolved
                    print("🔔 DELEGATE: Resolved token name to display name: \(appName)")
                }
            }
            print("🔔 DELEGATE: App name from notification: \(appName)")

            // Check if Continue was already pressed (isInterventionActive should be true)
            let sharedData = SharedDataManager.shared
            let currentActive = sharedData.loadInterventionActive()
            let currentApp = sharedData.loadPendingAppToUnlock()

            print("🔔 DELEGATE: Current state - active: \(currentActive), app: \(currentApp ?? "nil")")

            // ONLY show intervention if Continue was pressed (isInterventionActive = true)
            if currentActive {
                print("🔔 DELEGATE: ✅ Continue was pressed - showing intervention")

                // Only update shared storage if we have a real display name (not a fallback).
                // The raw token key in storage is needed for unlock/breakthrough matching.
                if appName != "the app" && appName != "this app" && !appName.hasPrefix("app_") {
                    sharedData.savePendingAppToUnlock(appName)
                }

                // Post notification to trigger UI update
                print("🔔 DELEGATE: About to post ShowInterventionSheet notification on main thread...")
                DispatchQueue.main.async {
                    print("🔔 DELEGATE: 📤 POSTING ShowInterventionSheet notification NOW!")
                    NotificationCenter.default.post(name: NSNotification.Name("ShowInterventionSheet"), object: nil)
                    print("🔔 DELEGATE: ✅ Posted ShowInterventionSheet notification")
                }
            } else {
                print("🔔 DELEGATE: ⚠️ Continue not pressed yet - ignoring notification tap")
                print("🔔 DELEGATE: User must press 'Continue' on shield first")
            }
        } else {
            print("🔔 DELEGATE: ❌ Not an intervention notification - action: \(userInfo["action"] ?? "nil")")
        }

        print("🔔 DELEGATE: ============================================")
        completionHandler()
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 DELEGATE: Notification will present in foreground")
        print("🔔 DELEGATE: Notification ID: \(notification.request.identifier)")

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}
