import Foundation

/// The "fridge note": remembers that a specific alarm's mission was finished on a specific day.
/// Key = "<alarmId>|<yyyy-MM-dd>". Every backup carries its parent alarm's id, so any backup
/// that fires can ask "is MY alarm already done today?" and self-dismiss — no fragile per-batch
/// matching. Set on completion, cleared when that alarm's burst is (re-)armed (so re-using an
/// alarm the same day works), and a recurring alarm's next day is a different key (so it rings).
enum AlarmDoneStore {
    private static let key = "alarmDoneOccurrences_v1"
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func occ(_ alarmId: String, _ date: Date) -> String {
        "\(alarmId)|\(formatter.string(from: date))"
    }

    static func markDone(alarmId: String, on date: Date = Date()) {
        var set = load()
        set.insert(occ(alarmId, date))
        // Keep only today's and yesterday's notes so the set can't grow forever.
        let keep = [formatter.string(from: Date()),
                    formatter.string(from: Date().addingTimeInterval(-86_400))]
        set = set.filter { entry in keep.contains(where: { entry.hasSuffix("|\($0)") }) }
        save(set)
    }

    static func isDone(alarmId: String, on date: Date = Date()) -> Bool {
        load().contains(occ(alarmId, date))
    }

    static func clear(alarmId: String, on date: Date = Date()) {
        var set = load()
        set.remove(occ(alarmId, date))
        save(set)
    }

    private static func load() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Set<String>.self, from: data) else { return [] }
        return s
    }
    private static func save(_ set: Set<String>) {
        if let data = try? JSONEncoder().encode(set) { UserDefaults.standard.set(data, forKey: key) }
    }
}

/// Tracks which days the user finished an alarm mission, for the Home-screen weekly tracker.
/// Stored under the same "alarmCompletedDays" key the tracker reads, as a JSON Set<String> of "yyyy-MM-dd".
/// Not availability-gated so it can be called from the mission dismiss flow.
enum AlarmCompletionStore {
    static let key = "alarmCompletedDays"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func load() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return decoded
    }

    /// Whether the given day (default today) already has a completion recorded.
    static func hasCompleted(_ date: Date = Date()) -> Bool {
        load().contains(formatter.string(from: date))
    }

    /// Marks the given day (default today) as completed.
    static func markCompleted(_ date: Date = Date()) {
        var days = load()
        days.insert(formatter.string(from: date))
        if let encoded = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    /// Current streak: replays every day since the first completion — **+1 for each
    /// completed day, −3 for each fully-missed day** (today doesn't count as missed
    /// until it's over), floored at 0.
    static func currentStreak(asOf now: Date = Date()) -> Int {
        let days = load()
        guard !days.isEmpty else { return 0 }

        let cal = Calendar.current
        let dates = days.compactMap { formatter.date(from: $0) }
        guard let earliest = dates.min() else { return 0 }

        let today = cal.startOfDay(for: now)
        var day = cal.startOfDay(for: earliest)
        var score = 0

        while day <= today {
            let key = formatter.string(from: day)
            if days.contains(key) {
                score += 1
            } else if day < today {
                // a fully-elapsed day with no completion
                score -= 3
            }
            score = max(0, score)
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return score
    }
}

/// Shared persistence + AlarmKit wiring for user-created alarms.
/// Both the Alarms tab and the Home screen read/write through here so they
/// stay in sync with each other and with the OS.
@available(iOS 16.0, *)
enum AlarmScheduler {
    private static let storageKey = "savedAlarms"

    // MARK: - Persistence

    static func loadAlarms() -> [AlarmItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveAlarms(_ alarms: [AlarmItem]) {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - AlarmKit wiring

    /// Schedules the alarm with AlarmKit if enabled, or cancels it if disabled,
    /// then refreshes which alarm holds the backup burst.
    static func sync(_ alarm: AlarmItem) {
        if alarm.isEnabled {
            schedule(alarm)
        } else {
            cancel(alarm)
        }
        refresh()
    }

    static func schedule(_ alarm: AlarmItem) {
        guard #available(iOS 26.1, *) else { return }

        // Bridge mission data to MainAppView, which reads this key when the alarm fires.
        // Pipe-joined so a 2-mission alarm round-trips ("Item Search|Solve Math").
        UserDefaults.standard.set(alarm.missionList.joined(separator: "|"), forKey: "alarmMission_\(alarm.id.uuidString)")
        UserDefaults.standard.set(alarm.selectedObjects ?? [], forKey: "alarmItems_\(alarm.id.uuidString)")

        // Remember when a one-time alarm is due, so we can auto-disable it after it passes.
        let isOneTime = !alarm.isScheduled || alarm.repeatDays.isEmpty
        if isOneTime, let fire = nextFireDate(for: alarm) {
            UserDefaults.standard.set(fire, forKey: "alarmFireDate_\(alarm.id.uuidString)")
        }

        // AlarmItem indexes days as Mon=0...Sun=6; AlarmService expects Sun=0...Sat=6.
        let serviceDays = Set(alarm.repeatDays.map { ($0 + 1) % 7 })
        let repeatDays = alarm.isScheduled ? serviceDays : []

        Task {
            let service = AlarmService.shared
            if !service.isAuthorized {
                let granted = await service.requestAuthorization()
                guard granted else {
                    print("⏰ SCHEDULER: AlarmKit authorization denied — \(alarm.name) not scheduled")
                    return
                }
            }
            do {
                _ = try await service.scheduleAlarm(
                    id: alarm.id,
                    hour: alarm.hour,
                    minute: alarm.minute,
                    repeatDays: repeatDays,
                    name: alarm.name,
                    missionType: alarm.mission,   // first mission — used for the alert button label
                    selectedItems: [],
                    sound: AlarmService.alertSound(for: alarm.sound)
                )
                print("⏰ SCHEDULER: Scheduled \(alarm.name) at \(alarm.hour):\(alarm.minute) [\(alarm.mission)]")
            } catch {
                print("⏰ SCHEDULER: Failed to schedule \(alarm.name): \(error)")
            }
        }
    }

    static func cancel(_ alarm: AlarmItem) {
        guard #available(iOS 26.1, *) else { return }
        UserDefaults.standard.removeObject(forKey: "alarmMission_\(alarm.id.uuidString)")
        UserDefaults.standard.removeObject(forKey: "alarmItems_\(alarm.id.uuidString)")
        UserDefaults.standard.removeObject(forKey: "alarmFireDate_\(alarm.id.uuidString)")
        AlarmService.shared.cancelAlarm(id: alarm.id)
        cancelBackups(primaryId: alarm.id.uuidString)
    }

    // MARK: - Backup alarms (anti-skip)

    /// Seconds after the primary fires to re-ring. A tapered chain covering ~35 minutes, all
    /// pre-scheduled up front so it survives the user force-quitting every alarm without ever
    /// opening the app (no reliance on the app running to extend coverage):
    ///   • dense:  every 20s for the first 5 min  (15 backups)
    ///   • sparse: every 40s for the next 30 min  (45 backups)
    /// = 60 backups. Only the SINGLE soonest alarm ever holds a chain (see refreshSoonestBackups),
    /// so the AlarmKit quota stays ~60 + one-per-other-alarm.
    private static let backupOffsets: [TimeInterval] = {
        let dense  = stride(from: 20.0,  through: 300.0,  by: 20.0)  // first 5 min, 20s apart
        let sparse = stride(from: 340.0, through: 2100.0, by: 40.0)  // next 30 min, 40s apart
        return Array(dense) + Array(sparse)
    }()

    /// Pre-schedules a burst of one-shot backup alarms around the primary's next fire.
    /// They're registered with the system up front, so they survive a force-quit and
    /// re-ring until the mission is completed (which cancels the pending ones).
    private static func armBackups(for alarm: AlarmItem, from base: Date) {
        guard #available(iOS 26.1, *) else { return }

        // Fresh burst → this occurrence is NOT done (clears any old "done" note for this
        // alarm on the burst's fire date, so re-using/re-arming makes it ring again).
        AlarmDoneStore.clear(alarmId: alarm.id.uuidString, on: base)

        // Clear any stale backups for this alarm before laying down a fresh set.
        cancelBackups(primaryId: alarm.id.uuidString)

        let defaults = UserDefaults.standard
        let sound = AlarmService.alertSound(for: alarm.sound)
        var backupIds: [String] = []
        var lastFire = base

        for offset in backupOffsets {
            let backupId = UUID()
            let fire = base.addingTimeInterval(offset)
            lastFire = fire
            backupIds.append(backupId.uuidString)
            // Mission bridge + reverse map back to the primary for cancellation.
            defaults.set(alarm.missionList.joined(separator: "|"), forKey: "alarmMission_\(backupId.uuidString)")
            defaults.set(alarm.selectedObjects ?? [], forKey: "alarmItems_\(backupId.uuidString)")
            defaults.set(alarm.id.uuidString, forKey: "alarmBackupPrimary_\(backupId.uuidString)")
            Task {
                do {
                    try await AlarmService.shared.scheduleOneShot(
                        id: backupId,
                        date: fire,
                        name: alarm.name,
                        missionType: alarm.mission,
                        sound: sound
                    )
                } catch {
                    print("⏰ SCHEDULER: Backup schedule failed: \(error)")
                }
            }
        }

        defaults.set(backupIds, forKey: "alarmBackups_\(alarm.id.uuidString)")

        // One session for this whole firing — primary + every backup share it. Completion
        // marks it done; any leftover that fires later reads it and self-dismisses.
        WakeSessionStore.upsert(WakeSession(
            id: UUID().uuidString,
            alarmId: alarm.id.uuidString,
            primaryAlarmKitID: alarm.id.uuidString,
            backupAlarmKitIDs: backupIds,
            completedAt: nil,
            lastBackupFire: lastFire,
            validUntil: lastFire.addingTimeInterval(WakeSessionStore.validGrace)
        ))
        print("⏰ SCHEDULER: Armed \(backupIds.count) backups + session for \(alarm.name)")
    }

    /// Cancels all pending backups for a primary alarm and clears their bookkeeping.
    static func cancelBackups(primaryId: String) {
        guard #available(iOS 26.1, *) else { return }
        let defaults = UserDefaults.standard
        guard let ids = defaults.array(forKey: "alarmBackups_\(primaryId)") as? [String] else { return }
        for idStr in ids {
            if let uuid = UUID(uuidString: idStr) {
                AlarmService.shared.terminate(id: uuid)   // stop if ringing, cancel if pending
            }
            defaults.removeObject(forKey: "alarmMission_\(idStr)")
            defaults.removeObject(forKey: "alarmItems_\(idStr)")
            defaults.removeObject(forKey: "alarmBackupPrimary_\(idStr)")
        }
        defaults.removeObject(forKey: "alarmBackups_\(primaryId)")
    }

    /// Resolves a fired alarm (primary or backup) to its PARENT alarm id, then reports whether
    /// that alarm's mission is already done for today (the "fridge note"). Resolves via the
    /// durable WakeSession record FIRST, because cancelBackups deletes the alarmBackupPrimary_
    /// pointer — without this, a late stray couldn't find its parent and would re-present.
    static func parentAlarmId(of alarmKitId: String) -> String {
        WakeSessionStore.session(forAlarmKitID: alarmKitId)?.alarmId
            ?? UserDefaults.standard.string(forKey: "alarmBackupPrimary_\(alarmKitId)")
            ?? alarmKitId
    }

    static func isAlarmDone(alarmKitId: String) -> Bool {
        AlarmDoneStore.isDone(alarmId: parentAlarmId(of: alarmKitId))
    }

    /// A stray fired but its alarm's mission is already done → silence THIS one AND take all of
    /// its siblings down with it (so one leftover firing cleans up the whole remaining group).
    static func handleStray(alarmKitId: UUID) {
        guard #available(iOS 26.1, *) else { return }
        let id = alarmKitId.uuidString
        AlarmService.shared.stopAlarm(id: alarmKitId)   // silence the stray that just fired

        // Cancel every sibling — via the durable session list (the bridge list may already be
        // gone after completion) AND the bridge list if it's still around.
        if let session = WakeSessionStore.session(forAlarmKitID: id) {
            for idStr in session.backupAlarmKitIDs {
                if let uuid = UUID(uuidString: idStr) { AlarmService.shared.terminate(id: uuid) }
            }
        }
        cancelBackups(primaryId: parentAlarmId(of: id))
    }

    // MARK: - Ghost guard + sweep

    /// A "ghost" is a fired alarm we can't connect to anything: it has NO mission info AND no
    /// parent in the saved-alarm list. These are leftovers whose bookkeeping was erased (the
    /// alarm was deleted/edited, or the app reinstalled) but whose AlarmKit alarm survived a
    /// failed cancel. Wake-up checks are NOT ghosts — they keep their mission bridge.
    static func isGhost(alarmKitId: String) -> Bool {
        // No mission id → it was cancelled / we don't know what to show → ghost. (Cancelling a
        // backup erases its mission id, so a fired alarm with none should never present.)
        guard let mission = UserDefaults.standard.string(forKey: "alarmMission_\(alarmKitId)") else { return true }
        // The wake-up check is legit even though it has no saved parent (transient one-shot).
        if mission == "Type Word" { return false }
        // Otherwise it's legit ONLY if it resolves to a real, currently-saved alarm. We do NOT
        // trust a stray mission id on its own — an orphan could keep one through a bookkeeping
        // mismatch and would then wrongly present a mission. Requiring a saved parent closes that.
        let parent = parentAlarmId(of: alarmKitId)
        return !loadAlarms().contains(where: { $0.id.uuidString == parent })
    }

    /// Idea A: cancel every scheduled alarm that's a ghost. Run when a ghost fires AND on every
    /// foreground (via reconcile), so ghosts are killed before they can ring. Best-effort — if a
    /// cancel fails, the fire-time guard still refuses to show a mission for it.
    static func sweepGhosts() {
        guard #available(iOS 26.1, *) else { return }
        for idStr in AlarmService.shared.currentAlarmIDs() where isGhost(alarmKitId: idStr) {
            if let uuid = UUID(uuidString: idStr) { AlarmService.shared.terminate(id: uuid) }
            print("👻 SCHEDULER: Swept ghost alarm \(idStr)")
        }
    }

    /// A parentless ghost fired → silence it and sweep the rest. NEVER presents a mission.
    static func dismissGhost(alarmKitId: UUID) {
        guard #available(iOS 26.1, *) else { return }
        AlarmService.shared.stopAlarm(id: alarmKitId)
        sweepGhosts()
    }

    /// Call when a mission is completed. Stops the ringing alarm (primary or a backup)
    /// and cancels every still-pending backup in its group, then refreshes (which disables
    /// a passed one-time alarm and moves the backup burst to the next soonest alarm).
    static func completeMission(firedAlarmId: UUID) {
        guard #available(iOS 26.1, *) else { return }
        let defaults = UserDefaults.standard
        let firedKey = firedAlarmId.uuidString

        // A backup carries a pointer to its primary; otherwise the fired alarm IS the primary.
        let primaryId = defaults.string(forKey: "alarmBackupPrimary_\(firedKey)") ?? firedKey

        // Mark the SESSION complete and PERSIST FIRST. From now on, any leftover backup that
        // fires reads this and self-dismisses — even if the best-effort cancels below fail.
        // This is what kills the double-mission / loop for good.
        let session = WakeSessionStore.session(forAlarmKitID: firedKey)
            ?? WakeSessionStore.activeSession(forAlarmId: primaryId)
        if let session { WakeSessionStore.markCompleted(sessionID: session.id) }

        // The "fridge note": this alarm's mission is done for today. EVERY backup of this alarm
        // shares this one note, so any leftover that fires later reads it and self-dismisses —
        // this is the reliable fix for the recurring double-mission / "did 5 missions" bug.
        AlarmDoneStore.markDone(alarmId: primaryId)
        print("🔔 SESSIONLOG COMPLETE: firedKey=\(firedKey) primaryId=\(primaryId) → markedSession=\(session?.id ?? "nil") ownerAlarmId=\(session?.alarmId ?? "nil")")

        // Best-effort cleanup: stop the ringing alarm(s) — STOP (not cancel) the primary so a
        // recurring alarm keeps tomorrow's schedule. Terminate the one-shot backups.
        AlarmService.shared.stopAlarm(id: firedAlarmId)
        if let primaryUUID = UUID(uuidString: primaryId), primaryUUID != firedAlarmId {
            AlarmService.shared.stopAlarm(id: primaryUUID)
        }
        if let session {
            for idStr in session.backupAlarmKitIDs {
                if let uuid = UUID(uuidString: idStr) { AlarmService.shared.terminate(id: uuid) }
            }
        }
        cancelBackups(primaryId: primaryId)

        // Wake-up Check: if the just-completed REAL alarm has it enabled, fire a second
        // type-the-word alarm 10 min later. (The check isn't in savedAlarms, so completing
        // the check finds nothing here → no infinite loop.)
        if let primaryUUID = UUID(uuidString: primaryId),
           let alarm = loadAlarms().first(where: { $0.id == primaryUUID }),
           alarm.wakeUpCheckEnabled {
            scheduleWakeUpCheck(for: alarm)
        }

        // A one-time alarm is "used up" only once its mission is actually completed.
        disableIfOneTime(primaryId: primaryId)

        refresh()
    }

    // MARK: - Wake-up Check (Step 1: single one-shot, no backups)

    private static let wakeUpWords = [
        "Morning", "Sunrise", "Awake", "Rise", "Today",
        "Bright", "Fresh", "Hello", "Energy", "Focus"
    ]

    /// Schedules a one-shot "type the word" alarm 10 minutes after a completed alarm.
    static func scheduleWakeUpCheck(for alarm: AlarmItem) {
        guard #available(iOS 26.1, *) else { return }
        let checkId = UUID()
        let word = wakeUpWords.randomElement() ?? "Morning"
        let fire = Date().addingTimeInterval(10 * 60)

        // Bridge: MainAppView reads these to present the typing mission with the word.
        UserDefaults.standard.set("Type Word", forKey: "alarmMission_\(checkId.uuidString)")
        UserDefaults.standard.set([word], forKey: "alarmItems_\(checkId.uuidString)")

        let sound = AlarmService.alertSound(for: alarm.sound)
        Task {
            do {
                try await AlarmService.shared.scheduleOneShot(
                    id: checkId,
                    date: fire,
                    name: "Wake-up Check",
                    missionType: "Type Word",
                    sound: sound
                )
                print("⏰ SCHEDULER: Wake-up check scheduled +10m [word: \(word)]")
            } catch {
                print("⏰ SCHEDULER: Wake-up check failed: \(error)")
            }
        }
    }

    // MARK: - One-time migration wipe

    /// On first launch of the session-based system, flush EVERY existing AlarmKit alarm (to
    /// clear pre-existing "ghosts" from the old backup system that reconcile can't know about),
    /// then rebuild cleanly from the saved list. Runs exactly once.
    static func migrateWipeIfNeeded() {
        guard #available(iOS 26.1, *) else { return }
        let flag = "didWipeForSessionMigration_v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)

        let defaults = UserDefaults.standard
        // Kill every alarm currently on the books + clear its mission bridge.
        for idStr in AlarmService.shared.terminateAll() {
            defaults.removeObject(forKey: "alarmMission_\(idStr)")
            defaults.removeObject(forKey: "alarmItems_\(idStr)")
            defaults.removeObject(forKey: "alarmBackupPrimary_\(idStr)")
        }
        defaults.removeObject(forKey: "currentBackupPrimaryID")
        defaults.removeObject(forKey: "currentBackupFireDate")

        // Rebuild from the user's saved alarms.
        for alarm in loadAlarms() where alarm.isEnabled {
            schedule(alarm)
        }
        print("⏰ SCHEDULER: One-time wipe + rebuild complete")
    }

    // MARK: - Reconciliation (sweep leftovers)

    /// Layers 3 & 4: sweep leftovers. Cancels every backup belonging to a session that's
    /// completed or past its validUntil, then prunes those sessions. Safe + cheap; runs on
    /// every foreground so ghosts can never accumulate (and a post-completion stray that
    /// fired gets killed before it can fire again).
    static func reconcile() {
        guard #available(iOS 26.1, *) else { return }
        let defaults = UserDefaults.standard
        for idStr in WakeSessionStore.staleBackupIDs() {
            if let uuid = UUID(uuidString: idStr) { AlarmService.shared.terminate(id: uuid) }
            defaults.removeObject(forKey: "alarmMission_\(idStr)")
            defaults.removeObject(forKey: "alarmItems_\(idStr)")
            defaults.removeObject(forKey: "alarmBackupPrimary_\(idStr)")
        }
        WakeSessionStore.prune()
        // Also sweep parentless ghosts (deleted/edited/reinstalled leftovers) before they ring.
        sweepGhosts()
    }

    // MARK: - Refresh (reconcile + soonest-only backups)

    /// Cheap to call on app foreground / after any alarm change: sweep leftovers, top up an
    /// in-progress fight, and pre-arm the soonest upcoming alarm's burst.
    static func refresh() {
        // Keep the 6pm "tomorrow's alarms" reminder in sync with the current alarm list.
        if #available(iOS 16.0, *) {
            NotificationManager.shared.refreshTomorrowAlarmsReminder(alarms: loadAlarms())
        }
        guard #available(iOS 26.1, *) else { return }
        reconcile()
        refreshSoonestBackups()
    }

    /// Disables a one-time alarm once its mission is actually completed (NOT merely when its
    /// time passes — a slept-through one-time alarm should keep nagging until done).
    private static func disableIfOneTime(primaryId: String) {
        guard #available(iOS 26.1, *), let uuid = UUID(uuidString: primaryId) else { return }
        var alarms = loadAlarms()
        guard let idx = alarms.firstIndex(where: { $0.id == uuid }) else { return }
        let a = alarms[idx]
        let isOneTime = !a.isScheduled || a.repeatDays.isEmpty
        guard isOneTime, a.isEnabled else { return }
        alarms[idx].isEnabled = false
        saveAlarms(alarms)
        UserDefaults.standard.removeObject(forKey: "alarmFireDate_\(primaryId)")
        AlarmService.shared.cancelAlarm(id: uuid)  // remove the spent one-time alarm
    }

    // NOTE: Backups are intentionally NEVER cancelled around the mission opening/backgrounding.
    // They stay armed for the whole burst so a force-quit still re-rings. A backup that fires
    // while the mission is on screen, or after completion, is recognized via its WakeSession
    // and self-dismissed (see WakeSessionStore + the guard in MainAppView). Cleanup of
    // leftovers is handled by reconcile() on every foreground.

    /// Only the single soonest-upcoming alarm carries a backup burst. This caps total
    /// backup usage (so the AlarmKit per-app alarm quota isn't exhausted by many alarms)
    /// while letting that one burst be long and aggressive.
    static func refreshSoonestBackups() {
        guard #available(iOS 26.1, *) else { return }
        let defaults = UserDefaults.standard
        let now = Date()

        guard let soonest = nextAlarm(from: loadAlarms()) else {
            // No upcoming alarm → tear down any leftover burst.
            if let prevId = defaults.string(forKey: "currentBackupPrimaryID") { cancelBackups(primaryId: prevId) }
            defaults.removeObject(forKey: "currentBackupPrimaryID")
            defaults.removeObject(forKey: "currentBackupFireDate")
            return
        }

        // Does the SOONEST alarm ALREADY have its own live (not-completed, not-expired) burst?
        // If so, leave it alone — that's the actively-firing alarm we must not disturb (so a
        // mid-mission kill still re-rings). NOTE: we check the soonest alarm SPECIFICALLY, not
        // "any session is live" — a stale leftover session from a *different* alarm must NOT
        // block arming a brand-new alarm (that was the `session=nil`/no-re-ring bug).
        let soonestId = soonest.alarm.id.uuidString
        let alreadyArmed = WakeSessionStore.allSessions().values.contains {
            $0.alarmId == soonestId && $0.completedAt == nil && now <= $0.validUntil
        }
        if alreadyArmed { return }

        // (Re)arm the soonest. Tear down the previous burst first to free quota.
        if let prevId = defaults.string(forKey: "currentBackupPrimaryID") { cancelBackups(primaryId: prevId) }
        armBackups(for: soonest.alarm, from: soonest.date)
        defaults.set(soonestId, forKey: "currentBackupPrimaryID")
        defaults.set(soonest.date, forKey: "currentBackupFireDate")
    }

    // MARK: - Next-alarm computation

    /// The soonest upcoming fire date for an enabled alarm, or nil if it won't fire.
    static func nextFireDate(for alarm: AlarmItem, after now: Date = Date()) -> Date? {
        guard alarm.isEnabled else { return nil }
        let cal = Calendar.current

        func date(dayOffset: Int) -> Date? {
            guard let base = cal.date(byAdding: .day, value: dayOffset, to: now) else { return nil }
            return cal.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: base)
        }

        // One-time alarm: today if still in the future, otherwise tomorrow.
        if !alarm.isScheduled || alarm.repeatDays.isEmpty {
            if let today = date(dayOffset: 0), today > now { return today }
            return date(dayOffset: 1)
        }

        // Recurring alarm: find the next day whose weekday is in repeatDays.
        for offset in 0...7 {
            guard let candidate = date(dayOffset: offset), candidate > now else { continue }
            let weekday = cal.component(.weekday, from: candidate) // 1=Sun...7=Sat
            let alarmIndex = (weekday + 5) % 7                      // -> Mon=0...Sun=6
            if alarm.repeatDays.contains(alarmIndex) { return candidate }
        }
        return nil
    }

    /// The closest upcoming alarm across the list, paired with its next fire date.
    static func nextAlarm(from alarms: [AlarmItem], now: Date = Date()) -> (alarm: AlarmItem, date: Date)? {
        alarms
            .compactMap { alarm -> (alarm: AlarmItem, date: Date)? in
                guard let date = nextFireDate(for: alarm, after: now) else { return nil }
                return (alarm, date)
            }
            .min { $0.date < $1.date }
    }
}
