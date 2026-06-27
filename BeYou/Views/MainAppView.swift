import SwiftUI
import UserNotifications

@available(iOS 16.0, *)
struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var selectedTab: MainTab = .home
    @State private var showInterventionSheet = false
    @State private var showWriteReviewSheet = false
    @State private var showAlarmMission = false
    @State private var alertingAlarmId: UUID?
    @AppStorage("completedInterventionCount") private var completedInterventionCount: Int = 0
    @AppStorage("hasWrittenReview") private var hasWrittenReview: Bool = false
    @AppStorage("nextWriteReviewAt") private var nextWriteReviewAt: Int = 3
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Native TabView → Apple's standard tab bar (Liquid Glass on iOS 26).
        TabView(selection: $selectedTab) {
            AlarmHomeView()
                .tag(MainTab.home)
                .tabItem { Label(MainTab.home.label, systemImage: MainTab.home.sfSymbol) }

            AlarmsView()
                .tag(MainTab.alarms)
                .tabItem { Label(MainTab.alarms.label, systemImage: MainTab.alarms.sfSymbol) }

            InsightsView()
                .tag(MainTab.insights)
                .tabItem { Label(MainTab.insights.label, systemImage: MainTab.insights.sfSymbol) }

            SettingsView()
                .tag(MainTab.settings)
                .tabItem { Label(MainTab.settings.label, systemImage: MainTab.settings.sfSymbol) }
        }
        .sheet(isPresented: $showInterventionSheet) {
            InterventionSheet()
        }
        .sheet(isPresented: $showWriteReviewSheet) {
            WriteReviewSheet(
                onWriteReview: {
                    ReviewPromptManager.markWritten()
                    hasWrittenReview = true
                    showWriteReviewSheet = false
                    AnalyticsManager.shared.track("Write Review Tapped")
                    if let url = URL(string: "https://apps.apple.com/app/id6760232059?action=write-review") {
                        UIApplication.shared.open(url)
                    }
                },
                onDismiss: {
                    ReviewPromptManager.clearPending()
                    showWriteReviewSheet = false
                }
            )
        }
        .fullScreenCover(isPresented: $showAlarmMission) {
            if let alarmId = alertingAlarmId {
                let raw = UserDefaults.standard.string(forKey: "alarmMission_\(alarmId.uuidString)") ?? "Item Search"
                let missions = raw.split(separator: "|").map(String.init)
                let itemsData = UserDefaults.standard.stringArray(forKey: "alarmItems_\(alarmId.uuidString)") ?? []
                AlarmDismissFlowView(
                    alarmId: alarmId,
                    alarmName: "Alarm",
                    missions: missions.isEmpty ? ["Item Search"] : missions,
                    selectedItems: itemsData,
                    onDismissed: {
                        showAlarmMission = false
                        alertingAlarmId = nil
                    }
                )
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                NotificationManager.shared.clearBadge()   // reset the app-icon badge on open
                // Full refresh on foreground (sweep leftovers + re-arm the soonest alarm's burst).
                // Done here once per foreground — NOT on every tab switch (that was the lag).
                if #available(iOS 26.1, *) { AlarmScheduler.refresh() }
                checkForPendingIntervention()
                checkForWriteReviewPrompt()
                checkForAlertingAlarm()
                checkForPendingMission()
                // Returning to a mission in progress → resume the gapless loop.
                if showAlarmMission, let id = alertingAlarmId {
                    MissionAlarmAudio.shared.start(sound: soundForAlarm(id)) {
                        if #available(iOS 26.1, *) { AlarmService.shared.stopAlarm(id: id) }
                    }
                }
            } else if newPhase == .background {
                // Backgrounded or locked → RELEASE the audio channel. A suspended app that keeps
                // the .playback session holds the audio hostage, which MUTES the system backup
                // alarms (they fire and wake the screen but make no sound). Letting go here means
                // the real alarms ring normally while we're away; the loop restarts on return.
                // (This is what made "kill = rings, background = silent" — now background frees it
                // too.) We use .background (not transient .inactive) so the loop stays gapless
                // during the mission and only releases when you actually leave/lock.
                MissionAlarmAudio.shared.stop()
            }
            // NOTE: we deliberately do NOT cancel/re-arm backups around backgrounding. The
            // backup burst stays armed the whole time so a force-quit still re-rings; any
            // backup that fires while the mission is open is auto-dismissed by the guard.
        }
        .onChange(of: showAlarmMission) { showing in
            if showing {
                // Play the alarm on a continuous loop for the whole mission (gapless). The system
                // alarm is silenced ONLY once the loop is confirmed playing (in onStarted), so a
                // failed audio-session start can never leave us in silence — the alarm keeps
                // ringing until the loop takes over. Backups stay armed for kill-safety.
                if let id = alertingAlarmId {
                    MissionAlarmAudio.shared.start(sound: soundForAlarm(id)) {
                        if #available(iOS 26.1, *) { AlarmService.shared.stopAlarm(id: id) }
                    }
                }

                // Alarm fired → engage the App Block (if armed). It stays until the user stops it
                // via the unblock flow — completing the mission does NOT lift it.
                if AppBlockStore.isEnabled && !AppBlockStore.isActive {
                    screenTimeManager.activateAppBlock()
                }
            } else {
                MissionAlarmAudio.shared.stop()
                // Mission closed → clear any leftover "pending mission" flag (set when a backup
                // was tapped mid-mission) so it can't silently re-open the mission later.
                UserDefaults.standard.removeObject(forKey: "pendingMissionAlarmID")

                // If the just-completed alarm queued a review prompt, show it now.
                if ReviewPromptManager.isPending && !hasWrittenReview {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showWriteReviewSheet = true
                    }
                }
            }
        }
        .onChange(of: appState.isInterventionActive) { isActive in
            print("🔄 MAIN: onChange triggered - isInterventionActive changed to: \(isActive)")
            print("🔄 MAIN: pendingAppToUnlock: \(appState.pendingAppToUnlock ?? "nil")")

            let shouldShow = isActive && appState.pendingAppToUnlock != nil && !showInterventionSheet
            print("🔄 MAIN: Should show sheet: \(shouldShow) (already showing: \(showInterventionSheet))")

            if shouldShow {
                print("🔄 MAIN: ✅ Showing intervention sheet!")
                showInterventionSheet = true
            } else {
                print("🔄 MAIN: ❌ NOT showing sheet via onChange")
            }
        }
        .onAppear {
            NotificationManager.shared.clearBadge()   // clear any stale app-icon badge
            retireMeditationIfNeeded()   // remove any leftover meditation block (feature retired)
            // One-time: flush pre-existing ghost alarms from the old system, then rebuild.
            if #available(iOS 26.1, *) { AlarmScheduler.migrateWipeIfNeeded() }
            // Full refresh on launch (sweep leftovers + arm the soonest alarm's backups).
            if #available(iOS 26.1, *) { AlarmScheduler.refresh() }
            checkForPendingIntervention()
            setupNotificationListener()
            checkForAlertingAlarm()
            checkForPendingMission()

            // Show the mission when an alarm starts ringing while the app is already open.
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AlarmDidStartAlerting"),
                object: nil,
                queue: .main
            ) { _ in
                checkForAlertingAlarm()
            }
        }
    }

    /// One-time cleanup: the Meditation feature was retired, so lift any leftover meditation
    /// block, stop its background schedules, and clear stored times — otherwise a user with
    /// old meditation times could get blocked with no way to unblock.
    private func retireMeditationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "didRetireMeditation") else { return }
        screenTimeManager.deactivateMeditationBlock()
        screenTimeManager.registerMeditationSchedules(times: [])
        SharedDataManager.shared.saveMeditationTimes([])
        UserDefaults.standard.set(true, forKey: "didRetireMeditation")
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
            print("🔍 MAIN: Intervention detected! Showing sheet...")
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

    private func checkForWriteReviewPrompt() {
        guard !hasWrittenReview,
              !showInterventionSheet,
              !showAlarmMission,
              ReviewPromptManager.isPending else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showWriteReviewSheet = true
        }
    }

    private func checkForAlertingAlarm() {
        guard #available(iOS 26.1, *) else { return }
        let service = AlarmService.shared
        guard let alarmId = service.currentAlertingAlarmId else { return }

        // A mission is already on screen. If the continuous loop is playing, silence this
        // freshly-fired backup so it doesn't double up; if the loop somehow isn't playing,
        // leave it ringing (never create silence). Either way, don't re-present.
        if showAlarmMission {
            if MissionAlarmAudio.shared.isPlaying { service.stopAlarm(id: alarmId) }
            return
        }

        // Occurrence already completed → this is a stale leftover backup. Dismiss it and
        // do NOT show the mission again (the double-mission guard — the one safety net we keep).
        if isCompletedOccurrence(for: alarmId.uuidString) {
            logSessionResolution("DISMISS(alerting)", alarmId.uuidString)
            service.stopAlarm(id: alarmId)
            return
        }

        logSessionResolution("PRESENT(alerting)", alarmId.uuidString)
        alertingAlarmId = alarmId
        showAlarmMission = true
    }

    /// Presents the mission when the user used "slide to stop" — which routes through the
    /// app (StopAlarmIntent) and flags the mission as still owed, instead of dismissing it.
    private func checkForPendingMission() {
        // Already in a mission — ignore for now.
        guard !showAlarmMission else { return }
        guard let idStr = UserDefaults.standard.string(forKey: "pendingMissionAlarmID"),
              !idStr.isEmpty,
              let alarmId = UUID(uuidString: idStr) else { return }

        // Consume the flag so it doesn't re-trigger.
        UserDefaults.standard.removeObject(forKey: "pendingMissionAlarmID")

        // Stale leftover (mission already done for this occurrence) → dismiss, don't present.
        if isCompletedOccurrence(for: idStr) {
            logSessionResolution("DISMISS(pending)", idStr)
            if #available(iOS 26.1, *) { AlarmService.shared.stopAlarm(id: alarmId) }
            return
        }

        logSessionResolution("PRESENT(pending)", idStr)
        alertingAlarmId = alarmId
        showAlarmMission = true
    }

    /// Diagnostic: logs which session a fired/tapped alarm resolves to and whether it's
    /// completed — so a stray that still presents the mission tells us exactly why the guard
    /// missed it (no session vs. wrong/incomplete session).
    private func logSessionResolution(_ tag: String, _ alarmKitId: String) {
        let sid = WakeSessionStore.map()[alarmKitId] ?? "nil"
        let session = WakeSessionStore.session(forAlarmKitID: alarmKitId)
        let completed = session?.completedAt.map { "\($0)" } ?? "nil"
        let owningAlarm = session?.alarmId ?? "nil"
        print("🔔 SESSIONLOG \(tag): alarmKitId=\(alarmKitId) → session=\(sid) completedAt=\(completed) ownerAlarmId=\(owningAlarm)")
    }

    /// Whether the alarm's session (shared by its primary + all backups) is already completed.
    /// Any leftover backup that fires resolves to the same session → self-dismisses → no loop.
    private func isCompletedOccurrence(for alarmKitId: String) -> Bool {
        WakeSessionStore.isCompleted(alarmKitID: alarmKitId)
    }

    /// The user-chosen sound for the alarm that's firing (resolving a backup back to its
    /// primary), used to drive the continuous mission loop. Falls back to "Default".
    private func soundForAlarm(_ alarmId: UUID) -> String {
        // An explicit sound stored with this alarm (e.g. the wake-up check) wins.
        if let stored = UserDefaults.standard.string(forKey: "alarmSound_\(alarmId.uuidString)") { return stored }
        let primaryId = UserDefaults.standard.string(forKey: "alarmBackupPrimary_\(alarmId.uuidString)") ?? alarmId.uuidString
        return AlarmScheduler.loadAlarms().first { $0.id.uuidString == primaryId }?.sound ?? "Default"
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
