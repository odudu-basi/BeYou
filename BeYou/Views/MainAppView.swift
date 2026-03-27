import SwiftUI
import UserNotifications

@available(iOS 16.0, *)
struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var selectedTab: MainTab = .home
    @State private var showInterventionSheet = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Content
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .motivation:
                    MotivationView()
                case .settings:
                    SettingsView()
                }
            }

            // Custom Tab Bar
            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showInterventionSheet) {
            InterventionSheet()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                checkForPendingIntervention()
                // Delay re-applying blocks to allow unlock state to fully persist
                // Prevents race condition where reapply reads stale data after intervention
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    screenTimeManager.reapplyAllBlocks(appState: appState)
                }
            }
        }
        .onChange(of: appState.isInterventionActive) { isActive in
            print("🔄 MAIN: onChange triggered - isInterventionActive changed to: \(isActive)")
            print("🔄 MAIN: pendingAppToUnlock: \(appState.pendingAppToUnlock ?? "nil")")

            // Auto-show intervention sheet when intervention becomes active
            // Guard: don't show if already showing (prevents double trigger from Darwin + push)
            let shouldShow = isActive && appState.pendingAppToUnlock != nil && !showInterventionSheet
            print("🔄 MAIN: Should show sheet: \(shouldShow) (already showing: \(showInterventionSheet))")

            if shouldShow {
                print("🔄 MAIN: ✅ Showing intervention sheet via onChange!")
                showInterventionSheet = true
            } else {
                print("🔄 MAIN: ❌ NOT showing sheet via onChange")
            }
        }
        .onAppear {
            checkForPendingIntervention()
            setupNotificationListener()
        }
    }

    private func checkForPendingIntervention() {
        print("🔍 MAIN: Checking for pending intervention...")

        // Sync with shield migrations (e.g., token key -> display name)
        appState.syncFromSharedStorage()

        // Reload from shared storage to get latest state from shield
        let sharedData = SharedDataManager.shared
        let isInterventionActive = sharedData.loadInterventionActive()
        let pendingApp = sharedData.loadPendingAppToUnlock()

        print("🔍 MAIN: Found active=\(isInterventionActive), pendingApp=\(pendingApp ?? "nil")")

        // Update app state
        appState.isInterventionActive = isInterventionActive
        appState.pendingAppToUnlock = pendingApp
        print("🔍 MAIN: Updated app state")

        // Check if there's a pending intervention from the shield
        // Guard: don't show if already showing (prevents double trigger)
        if isInterventionActive && pendingApp != nil && !showInterventionSheet {
            print("🔍 MAIN: Intervention detected! Showing sheet if app is active...")

            // Show sheet if app is already active (user is in the app)
            showInterventionSheet = true
            print("🔍 MAIN: Sheet display triggered")
        } else {
            print("🔍 MAIN: No intervention pending (active=\(isInterventionActive), app=\(pendingApp ?? "nil"))")
        }
    }

    private func sendInterventionNotification(for appName: String) {
        print("📲 MAIN: Preparing to send notification for \(appName)")

        // Check notification authorization status first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📲 MAIN: Notification authorization status: \(settings.authorizationStatus.rawValue)")
            print("📲 MAIN: Alert setting: \(settings.alertSetting.rawValue)")

            guard settings.authorizationStatus == .authorized else {
                print("❌ MAIN: Notifications not authorized! Status: \(settings.authorizationStatus.rawValue)")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Ready to open the app?"
            content.body = "Tap to complete your mindful moment"
            content.sound = .default
            content.categoryIdentifier = "INTERVENTION_NOTIFICATION"
            content.userInfo = ["appName": appName, "action": "openIntervention"]

            print("📲 MAIN: Notification content created")

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "intervention_\(appName)_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )

            print("📲 MAIN: Adding notification request with ID: \(request.identifier)")

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ MAIN: Failed to send intervention notification: \(error)")
                } else {
                    print("✅ MAIN: Intervention notification successfully scheduled for \(appName)")
                }
            }
        }
    }

    private func setupNotificationListener() {
        print("🎧 MAIN: Setting up notification listener for ShowInterventionSheet")

        // Listen for intervention notification taps
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowInterventionSheet"),
            object: nil,
            queue: .main
        ) { _ in
            print("🎧 MAIN: ✅ RECEIVED ShowInterventionSheet notification!")

            // Sync with shield migrations before loading state
            appState.syncFromSharedStorage()

            // Reload state from shared storage
            let sharedData = SharedDataManager.shared
            let isActive = sharedData.loadInterventionActive()
            let pendingApp = sharedData.loadPendingAppToUnlock()

            print("🎧 MAIN: Loaded from shared storage - active: \(isActive), app: \(pendingApp ?? "nil")")

            appState.isInterventionActive = isActive
            appState.pendingAppToUnlock = pendingApp

            print("🎧 MAIN: Updated appState - active: \(appState.isInterventionActive), app: \(appState.pendingAppToUnlock ?? "nil")")

            // Show intervention sheet (guard against double trigger)
            if appState.isInterventionActive && appState.pendingAppToUnlock != nil && !showInterventionSheet {
                print("🎧 MAIN: ✅ Showing intervention sheet!")
                showInterventionSheet = true
            } else {
                print("🎧 MAIN: ❌ NOT showing sheet - active: \(appState.isInterventionActive), app: \(appState.pendingAppToUnlock ?? "nil"), already showing: \(showInterventionSheet)")
            }
        }

        print("🎧 MAIN: Notification listener setup complete")
    }
}
