import SwiftUI
import UserNotifications
import StoreKit

@available(iOS 16.0, *)
struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var selectedTab: MainTab = .home
    @State private var showInterventionSheet = false
    @State private var showWriteReviewSheet = false
    @State private var showAlarmMission = false
    @State private var alertingAlarmId: UUID?
    /// True once the current alarm's mission is recorded complete. While the dismiss flow is still
    /// on screen (completion + affirmation screens), this stops the foreground handler from
    /// re-arming the alarm audio for an alarm that's already finished. Reset when a new mission opens.
    @State private var missionCompleted = false
    /// Queued when a REAL alarm (not the wake-up check) completes; consumed when the alarm flow is
    /// dismissed to show the streak celebration on the home screen.
    @State private var pendingStreakCelebration = false
    @State private var showStreakCelebration = false
    @AppStorage("completedInterventionCount") private var completedInterventionCount: Int = 0
    @AppStorage("hasWrittenReview") private var hasWrittenReview: Bool = false
    @AppStorage("nextWriteReviewAt") private var nextWriteReviewAt: Int = 3
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

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
                // PHASE 2: resolve mission/items from the owner's CURRENT saved alarm (one source
                // of truth) instead of per-id sticky notes, so a leftover backup can't show a
                // stale mission after an edit. Falls back to bridges for the wake-up check.
                let resolved = AlarmScheduler.resolveFiring(alarmKitId: alarmId.uuidString)
                AlarmDismissFlowView(
                    alarmId: alarmId,
                    alarmName: "Alarm",
                    missions: resolved.missions.isEmpty ? ["Item Search"] : resolved.missions,
                    selectedItems: resolved.items,
                    exerciseSeconds: resolved.exerciseSeconds,
                    onDismissed: {
                        showAlarmMission = false
                        alertingAlarmId = nil
                    },
                    onCompleted: { shouldCelebrateStreak in
                        missionCompleted = true
                        // Streak celebration shows only on the FIRST real completion of the day.
                        pendingStreakCelebration = shouldCelebrateStreak
                    }
                )
                .environmentObject(appState)   // so the post-alarm affirmation card has appState
            }
        }
        // Streak celebration overlay — shown on the home screen after a real alarm completes.
        // Sits over the slightly-blurred app; tapping continue dismisses it and THEN lets the
        // review prompt evaluate (see onContinue), so the two never overlap.
        .overlay {
            if showStreakCelebration {
                StreakCelebrationView(
                    completedDays: AlarmCompletionStore.load(),
                    streak: AlarmCompletionStore.currentStreak(),
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.2)) { showStreakCelebration = false }
                        showReviewPromptIfNeeded(afterDelay: 0.4)
                    }
                )
                .transition(.opacity)
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
                // Returning to a mission STILL IN PROGRESS → resume the gapless loop. Skip once the
                // mission is complete: the completion/affirmation screens keep the flow (and
                // showAlarmMission) up, but the alarm is already off — re-arming it here would
                // replay a finished alarm and, on rapid background/foreground, crash the audio session.
                if showAlarmMission, !missionCompleted, let id = alertingAlarmId {
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
                // Fresh mission opening → clear the completed flag so the foreground handler will
                // resume the loop while THIS mission is in progress.
                missionCompleted = false
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

                // Deterministic sequencing (NO timer race): if a streak celebration is queued, show
                // it FIRST once the dismiss transition settles. The review prompt is intentionally
                // NOT scheduled here in that case — it's evaluated only after the user taps
                // "Continue" on the celebration (see the overlay's onContinue). Otherwise the
                // review prompt shows as it did before.
                if pendingStreakCelebration {
                    pendingStreakCelebration = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeInOut(duration: 0.25)) { showStreakCelebration = true }
                    }
                } else {
                    showReviewPromptIfNeeded(afterDelay: 0.8)
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
        showReviewPromptIfNeeded(afterDelay: 1.0)
    }

    /// Surfaces a queued review prompt, preferring Apple's NATIVE rating popup (raised on the very
    /// first completion) over the custom "Write a Review" sheet (days 2–3 / every 5th). Guarded so
    /// it never interrupts a mission or the intervention flow.
    private func showReviewPromptIfNeeded(afterDelay delay: Double) {
        guard !hasWrittenReview, !showInterventionSheet, !showAlarmMission, !showStreakCelebration else { return }

        if ReviewPromptManager.pendingNativeReview {
            ReviewPromptManager.pendingNativeReview = false
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { requestReview() }
        } else if ReviewPromptManager.isPending {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { showWriteReviewSheet = true }
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

    /// Whether this firing's alarm is already done. Checks the durable "fridge note" (parent
    /// alarm completed within the burst window) FIRST — robust even if the per-session lookup
    /// misses — then the per-session flag. Both are positive-only, so neither can silence a
    /// fresh alarm; a leftover that resolves to a recently-completed alarm self-dismisses → no loop.
    private func isCompletedOccurrence(for alarmKitId: String) -> Bool {
        // PHASE 3/5: the single owner+occurrence checklist is the authoritative "done" signal.
        // WakeSession.isCompleted remains as a secondary net (still load-bearing for burst timing)
        // until it too is retired.
        if #available(iOS 16.0, *), AlarmScheduler.isOccurrenceDone(alarmKitId: alarmKitId) { return true }
        return WakeSessionStore.isCompleted(alarmKitID: alarmKitId)
    }

    /// The user-chosen sound for the alarm that's firing, used to drive the continuous mission
    /// loop. PHASE 2: resolved from the owner's CURRENT saved alarm (one source of truth), with a
    /// legacy-bridge fallback for the wake-up check. Falls back to "Default".
    private func soundForAlarm(_ alarmId: UUID) -> String {
        AlarmScheduler.resolveFiring(alarmKitId: alarmId.uuidString).sound
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
