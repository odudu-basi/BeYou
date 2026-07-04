import Foundation

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

// PHASE 5: `AlarmDoneStore` (the time-windowed "fridge note") was removed — fully superseded by
// `OccurrenceCompletionStore`, which is keyed by owner+occurrence rather than a 40-minute window,
// so it can't expire mid-burst and every backup checks the exact same box. A freshly (re)scheduled
// alarm is inherently "not done" because its next fire is a FUTURE occurrence key that can't have
// been completed, so the old `clear()`-on-reschedule step is no longer needed either.

/// One firing's identity for an AlarmKit alarm: which user alarm owns it, and which occurrence
/// (day/time) it belongs to.
struct AlarmOwnerRef: Codable {
    let ownerAlarmId: String   // the user AlarmItem's UUID string
    let occurrenceKey: String  // which firing this is, e.g. "2026-06-30-01:26"
}

/// PHASE 1 of the self-contained redesign — the SINGLE owner map.
///
/// AlarmKit hands back only an alarm's `id` when it fires; it never returns the metadata we
/// attached (verified against the SDK — `Alarm` exposes only id/schedule/countdownDuration/state).
/// So to know which user alarm a fired alarm (primary OR backup) belongs to — and which day's
/// firing it is — we keep ONE atomic dictionary here instead of the ~60 scattered
/// `alarmBackupPrimary_…` keys. One write per burst, one read per lookup, so almost nothing can
/// drift, and a kill mid-write leaves at most this single value stale (healed by reconcile).
/// Everything else (mission/items/sound) is then read from the owner's AlarmItem — the real
/// source of truth — instead of per-alarm side-notes.
///
/// NOTE: Phase 1 only WRITES + maintains this map alongside the existing bridges; nothing reads it
/// yet. Reads/cleanup migrate to it in later phases, after which the scattered keys are deleted.
enum AlarmOwnerMap {
    private static let key = "alarmOwnerMap_v1"   // [alarmKitId: AlarmOwnerRef]

    private static let occFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HH:mm"
        return f
    }()

    /// A stable key for one firing of an alarm (drives per-occurrence completion in a later phase).
    static func occurrenceKey(for date: Date) -> String { occFormatter.string(from: date) }

    static func load() -> [String: AlarmOwnerRef] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: AlarmOwnerRef].self, from: data) else { return [:] }
        return decoded
    }
    private static func save(_ map: [String: AlarmOwnerRef]) {
        if let data = try? JSONEncoder().encode(map) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// Register several AlarmKit ids (a primary and/or its backups) under one owner+occurrence,
    /// in a SINGLE atomic write.
    static func register(alarmKitIds: [String], owner: String, occurrence: String) {
        guard !alarmKitIds.isEmpty else { return }
        var map = load()
        let ref = AlarmOwnerRef(ownerAlarmId: owner, occurrenceKey: occurrence)
        for id in alarmKitIds { map[id] = ref }
        save(map)
    }

    /// The owner user-alarm id for a fired AlarmKit id (primary or backup). Falls back to the id
    /// itself, so an unknown/pre-migration alarm still resolves to "itself".
    static func owner(of alarmKitId: String) -> String {
        load()[alarmKitId]?.ownerAlarmId ?? alarmKitId
    }

    static func ref(for alarmKitId: String) -> AlarmOwnerRef? { load()[alarmKitId] }

    /// Every AlarmKit id currently registered to this owner (for find-by-owner cancellation).
    static func alarmKitIds(forOwner owner: String) -> [String] {
        load().filter { $0.value.ownerAlarmId == owner }.map { $0.key }
    }

    /// Drop specific ids (after cancelling them) in one atomic write.
    static func remove(alarmKitIds: [String]) {
        guard !alarmKitIds.isEmpty else { return }
        var map = load()
        for id in alarmKitIds { map[id] = nil }
        save(map)
    }

    /// Drop every id belonging to an owner (when its burst/primary is torn down).
    static func removeOwner(_ owner: String) {
        save(load().filter { $0.value.ownerAlarmId != owner })
    }
}

/// PHASE 3 of the self-contained redesign — the SINGLE "done" checklist.
///
/// One record answers the only question that matters when an alarm rings: "did the user already
/// finish THIS firing?" It's keyed by `ownerAlarmId + occurrenceKey`, so **every** backup of one
/// firing checks the exact same box. That replaces the two older, drift-prone "done" systems:
///   • `AlarmDoneStore` (a 40-minute fridge-note window that could expire mid-burst), and
///   • `WakeSession.completedAt` (a per-firing flag that could be MISSED if the session lookup
///     failed — the root of the "mission that won't go away").
/// Because owner+occurrence is resolved from the atomic owner map, a straggler can never disagree
/// with the primary about whether the mission is done.
///
/// Per-occurrence (not per-day, not time-windowed): finishing today's 07:00 firing marks exactly
/// "owner|2026-06-30-07:00" done — tomorrow's 07:00 is a different key, so it rings fresh.
enum OccurrenceCompletionStore {
    private static let key = "completedOccurrences_v1"   // Set<"ownerAlarmId|occurrenceKey">

    private static func token(owner: String, occurrence: String) -> String { "\(owner)|\(occurrence)" }

    static func load() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else { return [] }
        return decoded
    }
    private static func save(_ set: Set<String>) {
        if let data = try? JSONEncoder().encode(set) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// Mark one firing (owner + occurrence) finished. Every backup of that firing self-dismisses.
    static func markDone(owner: String, occurrence: String) {
        var s = load()
        s.insert(token(owner: owner, occurrence: occurrence))
        save(s)
    }

    /// Whether this exact firing was already finished.
    static func isDone(owner: String, occurrence: String) -> Bool {
        load().contains(token(owner: owner, occurrence: occurrence))
    }

    /// Housekeeping: drop entries older than `keepDays` (the occurrence key starts with yyyy-MM-dd,
    /// which sorts lexicographically). Cheap; called from reconcile so the set can't grow forever.
    static func prune(keepDays: Int = 3, now: Date = Date()) {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -keepDays, to: cal.startOfDay(for: now)) else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let cutoffStr = df.string(from: cutoff)
        let current = load()
        let kept = current.filter { tok in
            guard let occ = tok.split(separator: "|").last else { return true }
            return String(occ.prefix(10)) >= cutoffStr   // keep occurrences on/after the cutoff day
        }
        if kept.count != current.count { save(kept) }
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

    /// Read-safe variant that distinguishes "genuinely no alarms" from "couldn't read." Returns
    /// `nil` ONLY when saved data exists but fails to decode (corruption / bad read). Callers that
    /// make DESTRUCTIVE decisions (e.g. cancelling backups whose owner seems gone) must refuse to
    /// act on a `nil` — a bad read must never be mistaken for "everything was deleted."
    static func loadAlarmsChecked() -> [AlarmItem]? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] } // none saved
        guard let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data) else { return nil } // unreadable
        return decoded
    }

    static func saveAlarms(_ alarms: [AlarmItem]) {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - Fired-alarm resolution (Phase 2)

    /// Everything the UI needs when an alarm rings.
    struct ResolvedFiring {
        var missions: [String]
        var items: [String]
        var sound: String
        var ownerAlarmId: String
    }

    /// Turns a fired AlarmKit id (primary, backup, or wake-up check) into the mission list, items,
    /// and sound to use — resolved from ONE source of truth. It looks up the owner via the owner
    /// map, then reads the owner's CURRENT `AlarmItem`, so a leftover backup can never ring a
    /// STALE mission/sound after an edit (the old wrong-mission / wrong-sound bug). Falls back to
    /// the legacy per-id bridges only for synthetic alarms (the wake-up check) and pre-migration
    /// leftovers whose owner is no longer a saved alarm.
    static func resolveFiring(alarmKitId: String) -> ResolvedFiring {
        let owner = AlarmOwnerMap.owner(of: alarmKitId)
        if let alarm = loadAlarms().first(where: { $0.id.uuidString == owner }) {
            return ResolvedFiring(
                missions: alarm.missionList,
                items: alarm.selectedObjects ?? [],
                sound: alarm.sound,
                ownerAlarmId: owner
            )
        }
        // Fallback: wake-up check / pre-migration leftover → legacy bridges (mirrors old logic).
        let d = UserDefaults.standard
        let raw = d.string(forKey: "alarmMission_\(alarmKitId)") ?? "Item Search"
        let missions = raw.split(separator: "|").map(String.init)
        let items = d.stringArray(forKey: "alarmItems_\(alarmKitId)") ?? []
        let legacyPrimary = d.string(forKey: "alarmBackupPrimary_\(alarmKitId)") ?? alarmKitId
        let sound = d.string(forKey: "alarmSound_\(alarmKitId)")
            ?? loadAlarms().first { $0.id.uuidString == legacyPrimary }?.sound
            ?? "Default"
        return ResolvedFiring(
            missions: missions.isEmpty ? ["Item Search"] : missions,
            items: items,
            sound: sound,
            ownerAlarmId: owner
        )
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

    /// Fire-and-forget primary (re)schedule — used by the automatic paths (toggle, Home, migration).
    /// The save UI uses `schedulePrimaryAwaiting` instead so it can hold a spinner until done.
    static func schedule(_ alarm: AlarmItem) {
        guard #available(iOS 26.1, *) else { return }
        let repeatDays = primaryPrep(alarm)
        Task { await performPrimarySchedule(alarm, repeatDays: repeatDays) }
    }

    /// Awaited primary (re)schedule: returns only once the primary is confirmed on the OS books
    /// (or the attempt fails). Same work as `schedule`, just awaitable so Save can wait on it.
    static func schedulePrimaryAwaiting(_ alarm: AlarmItem) async {
        guard #available(iOS 26.1, *) else { return }
        let repeatDays = primaryPrep(alarm)
        await performPrimarySchedule(alarm, repeatDays: repeatDays)
    }

    /// Synchronous bookkeeping done before the OS call: retire the old burst, write the mission
    /// bridge + owner-map entry, remember a one-time fire date, and return the AlarmKit repeat set.
    private static func primaryPrep(_ alarm: AlarmItem) -> Set<Int> {
        // An explicit (re)schedule retires the alarm's PREVIOUS firing: stop/cancel any burst
        // still armed (or ringing) for THIS alarm and mark its session done, so editing a ringing
        // or just-fired alarm doesn't leave the old one-shots re-ringing. Done BEFORE the re-arm.
        retireBurst(forAlarmId: alarm.id.uuidString)

        // (No "clear done" step needed: this reschedule's next fire is a FUTURE occurrence key,
        // which by definition can't already be marked done — so it always rings. See PHASE 5.)

        // Bridge mission data to MainAppView (pipe-joined so a 2-mission alarm round-trips).
        UserDefaults.standard.set(alarm.missionList.joined(separator: "|"), forKey: "alarmMission_\(alarm.id.uuidString)")
        UserDefaults.standard.set(alarm.selectedObjects ?? [], forKey: "alarmItems_\(alarm.id.uuidString)")

        // Remember when a one-time alarm is due, so we can auto-disable it after it passes.
        let isOneTime = !alarm.isScheduled || alarm.repeatDays.isEmpty
        if isOneTime, let fire = nextFireDate(for: alarm) {
            UserDefaults.standard.set(fire, forKey: "alarmFireDate_\(alarm.id.uuidString)")
        }

        // Register the primary in the owner map (occurrence = its next fire).
        if let fire = nextFireDate(for: alarm) {
            AlarmOwnerMap.register(
                alarmKitIds: [alarm.id.uuidString],
                owner: alarm.id.uuidString,
                occurrence: AlarmOwnerMap.occurrenceKey(for: fire)
            )
        }

        // AlarmItem indexes days as Mon=0...Sun=6; AlarmService expects Sun=0...Sat=6.
        let serviceDays = Set(alarm.repeatDays.map { ($0 + 1) % 7 })
        return alarm.isScheduled ? serviceDays : []
    }

    /// The OS-facing part of a (re)schedule: auth, confirmed teardown, then schedule + verify.
    private static func performPrimarySchedule(_ alarm: AlarmItem, repeatDays: Set<Int>) async {
        guard #available(iOS 26.1, *) else { return }
        let service = AlarmService.shared
        let idTag = String(alarm.id.uuidString.suffix(4))
        let timeStr = String(format: "%02d:%02d", alarm.hour, alarm.minute)
        print("⏰ SCHEDULER[\(idTag)]: BEGIN reschedule '\(alarm.name)' → \(timeStr) enabled=\(alarm.isEnabled) repeatDays=\(repeatDays.sorted()) sound=\(alarm.sound)")

        if !service.isAuthorized {
            let granted = await service.requestAuthorization()
            guard granted else {
                print("⏰ SCHEDULER[\(idTag)]: ABORT — AlarmKit authorization denied, '\(alarm.name)' not scheduled")
                return
            }
        }
        // Tear down any existing OS registration for this id FIRST, and WAIT until AlarmKit
        // confirms it's gone before re-adding (closes the duplicate / lagging-cancel races).
        await service.cancelAndWaitGone(id: alarm.id, tag: idTag)

        // The PRIMARY is the alarm that rings at the exact time, so it MUST land. Retry a few
        // times (schedule can transiently throw / not land) instead of silently giving up — a
        // swallowed failure here is a big cause of "didn't ring until I opened the app".
        for attempt in 1...3 {
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
                if service.isRegistered(id: alarm.id) {
                    print("⏰ SCHEDULER[\(idTag)]: OK scheduled '\(alarm.name)' at \(timeStr) [\(alarm.mission)] (try \(attempt))")
                    return
                }
                print("⏰ SCHEDULER[\(idTag)]: ⚠️ scheduled but NOT in OS list (try \(attempt)) — retrying")
            } catch {
                print("⏰ SCHEDULER[\(idTag)]: ❌ schedule attempt \(attempt) failed: \(error)")
            }
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s before retry
        }
        print("⏰ SCHEDULER[\(idTag)]: ❌ GAVE UP — '\(alarm.name)' primary not scheduled after 3 tries")
    }

    /// Minimum time the SAVE flow stays busy (spinner up) — a floor on top of the real
    /// confirmed-registration wait. Covers the daemon's durable-commit window and, with the
    /// background-time assertion, guarantees a protected execution window even if backgrounded.
    private static let minSaveDuration: TimeInterval = 5

    /// Awaited full setup for the SAVE flow: schedules the primary AND arms THIS alarm's own backup
    /// burst, then waits until that whole burst is confirmed on the OS books — so the UI can keep a
    /// spinner up until the alarm is genuinely armed. Backups are polled by their FRESH ids
    /// (unambiguous), so this can't return early. Also enforces a ~5s minimum so a fast schedule
    /// still gets a settle/commit buffer before the user can leave.
    static func syncAwaiting(_ alarm: AlarmItem) async {
        let started = Date()

        if #available(iOS 16.0, *) {
            NotificationManager.shared.refreshTomorrowAlarmsReminder(alarms: loadAlarms())
        }
        guard #available(iOS 26.1, *) else { return }

        if alarm.isEnabled {
            await schedulePrimaryAwaiting(alarm)          // primary confirmed before we continue
            if let fire = nextFireDate(for: alarm) {
                await armBackups(for: alarm, from: fire)  // arm THIS alarm's own burst (awaited)
            }
        } else {
            cancel(alarm)
        }

        reconcile()

        // Wait until every backup just armed for THIS alarm is actually on the OS books. These ids
        // are freshly minted, so "present" is unambiguous — no risk of returning before they land.
        let backupIds = AlarmOwnerMap.alarmKitIds(forOwner: alarm.id.uuidString)
            .filter { $0 != alarm.id.uuidString }
            .compactMap { UUID(uuidString: $0) }
        if !backupIds.isEmpty {
            _ = await AlarmService.shared.awaitRegistered(ids: backupIds, timeout: 30)
        }

        // Floor: keep the spinner up for at least `minSaveDuration`, even if everything landed fast.
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < minSaveDuration {
            try? await Task.sleep(nanoseconds: UInt64((minSaveDuration - elapsed) * 1_000_000_000))
        }
    }

    static func cancel(_ alarm: AlarmItem) {
        guard #available(iOS 26.1, *) else { return }
        UserDefaults.standard.removeObject(forKey: "alarmMission_\(alarm.id.uuidString)")
        UserDefaults.standard.removeObject(forKey: "alarmItems_\(alarm.id.uuidString)")
        UserDefaults.standard.removeObject(forKey: "alarmFireDate_\(alarm.id.uuidString)")
        AlarmService.shared.cancelAlarm(id: alarm.id)
        cancelBackups(primaryId: alarm.id.uuidString)
        // PHASE 1: forget every owner-map entry for this alarm (primary + any stragglers).
        AlarmOwnerMap.removeOwner(alarm.id.uuidString)
    }

    // MARK: - Backup alarms (anti-skip)

    /// Seconds after the primary fires to re-ring. A tapered chain covering ~35 minutes, all
    /// pre-scheduled up front so it survives the user force-quitting every alarm without ever
    /// opening the app (no reliance on the app running to extend coverage):
    ///   • dense:  every 20s for the first 5 min  (15 backups)
    ///   • sparse: every 40s for the next 30 min  (45 backups)
    /// = 60 backups. EVERY enabled alarm gets its own independent chain (see refreshAllBursts) —
    /// AlarmKit comfortably holds 1500+ alarms (verified), so bursts aren't rationed to one alarm.
    private static let backupOffsets: [TimeInterval] = {
        let dense  = stride(from: 20.0,  through: 300.0,  by: 20.0)  // first 5 min, 20s apart
        let sparse = stride(from: 340.0, through: 2100.0, by: 40.0)  // next 30 min, 40s apart
        return Array(dense) + Array(sparse)
    }()

    /// Pre-schedules a burst of one-shot backup alarms around the primary's next fire. They're
    /// registered with the system up front, so they survive a force-quit and re-ring until the
    /// mission is completed. Schedules all backups **in PARALLEL** and awaits them, so the whole
    /// burst lands in ~1–2s instead of ~15s one-at-a-time — shrinking the window where a
    /// background/kill can cut scheduling short (the "doesn't ring until I open the app" bug).
    private static func armBackups(for alarm: AlarmItem, from base: Date) async {
        guard #available(iOS 26.1, *) else { return }

        // Clear any stale backups for this alarm before laying down a fresh set.
        cancelBackups(primaryId: alarm.id.uuidString)

        let defaults = UserDefaults.standard
        let sound = AlarmService.alertSound(for: alarm.sound)
        var jobs: [(id: UUID, fire: Date)] = []
        var backupIds: [String] = []
        var lastFire = base

        for offset in backupOffsets {
            let backupId = UUID()
            let fire = base.addingTimeInterval(offset)
            lastFire = fire
            backupIds.append(backupId.uuidString)
            jobs.append((backupId, fire))
            // Mission bridge + reverse map back to the primary for cancellation.
            defaults.set(alarm.missionList.joined(separator: "|"), forKey: "alarmMission_\(backupId.uuidString)")
            defaults.set(alarm.selectedObjects ?? [], forKey: "alarmItems_\(backupId.uuidString)")
            defaults.set(alarm.id.uuidString, forKey: "alarmBackupPrimary_\(backupId.uuidString)")
        }

        defaults.set(backupIds, forKey: "alarmBackups_\(alarm.id.uuidString)")

        // Register the primary + every backup under one owner+occurrence in a SINGLE atomic write.
        AlarmOwnerMap.register(
            alarmKitIds: [alarm.id.uuidString] + backupIds,
            owner: alarm.id.uuidString,
            occurrence: AlarmOwnerMap.occurrenceKey(for: base)
        )

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

        // Fire all 60 schedules concurrently and wait for them to finish.
        let name = alarm.name, mission = alarm.mission
        await withTaskGroup(of: Void.self) { group in
            for job in jobs {
                group.addTask {
                    do {
                        try await AlarmService.shared.scheduleOneShot(
                            id: job.id, date: job.fire, name: name, missionType: mission, sound: sound
                        )
                    } catch {
                        print("⏰ SCHEDULER: Backup schedule failed: \(error)")
                    }
                }
            }
        }
        print("⏰ SCHEDULER: Armed \(backupIds.count) backups (parallel) + session for \(alarm.name)")
    }

    /// Cancels all pending backups for a primary alarm and clears their bookkeeping.
    static func cancelBackups(primaryId: String) {
        guard #available(iOS 26.1, *) else { return }
        let defaults = UserDefaults.standard

        // PHASE 4: cancel by OWNER. The authoritative set of this alarm's backups is the owner map
        // — it catches orphans from an earlier re-arm that the legacy `alarmBackups_` list lost
        // (the old "orphaned backups keep ringing" bug). We UNION with the legacy list for safety,
        // and EXCLUDE the primary id itself (owner == primary) so a recurring primary is preserved.
        var ids = Set(AlarmOwnerMap.alarmKitIds(forOwner: primaryId).filter { $0 != primaryId })
        if let legacy = defaults.array(forKey: "alarmBackups_\(primaryId)") as? [String] {
            ids.formUnion(legacy)
        }
        for idStr in ids {
            if let uuid = UUID(uuidString: idStr) {
                AlarmService.shared.terminate(id: uuid)   // stop if ringing, cancel if pending
            }
            defaults.removeObject(forKey: "alarmMission_\(idStr)")
            defaults.removeObject(forKey: "alarmItems_\(idStr)")
            defaults.removeObject(forKey: "alarmBackupPrimary_\(idStr)")
        }
        defaults.removeObject(forKey: "alarmBackups_\(primaryId)")
        AlarmOwnerMap.remove(alarmKitIds: Array(ids))
    }

    /// Retires any in-flight burst for a user alarm ahead of an explicit reschedule (edit/toggle).
    /// For every still-open WakeSession owned by this alarm it: marks the session completed (so any
    /// straggler that still manages to fire resolves to "done" and self-dismisses), and terminates
    /// its one-shot backups at the OS level (so a ringing/pending burst actually stops). Then it
    /// clears the soonest-burst pointer if it referenced this alarm and tears down the tracked
    /// backups — leaving a clean slate so refresh() arms a fresh burst at the NEW time, and the
    /// liveBurst guard can't keep the retired burst alive. Scoped strictly to this alarm id, so a
    /// different alarm's active burst is never touched.
    private static func retireBurst(forAlarmId alarmId: String) {
        guard #available(iOS 26.1, *) else { return }

        for (sid, session) in WakeSessionStore.allSessions()
        where session.alarmId == alarmId && session.completedAt == nil {
            WakeSessionStore.markCompleted(sessionID: sid)
            for idStr in session.backupAlarmKitIDs {
                if let uuid = UUID(uuidString: idStr) { AlarmService.shared.terminate(id: uuid) }
            }
            print("⏰ SCHEDULER: Retired session \(sid) (\(session.backupAlarmKitIDs.count) backups) for edited alarm \(alarmId.suffix(4))")
        }

        // Tear down the bookkeeping + any one-shots still tracked under this alarm id.
        cancelBackups(primaryId: alarmId)
        // PHASE 1: clear the owner map for this alarm; schedule() re-registers a fresh occurrence.
        AlarmOwnerMap.removeOwner(alarmId)
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

        // PHASE 3: mark this exact firing (owner + occurrence) done in the single checklist — the
        // authoritative "done" record every backup checks. Persist FIRST, before any cleanup, so a
        // straggler that fires later resolves to the same key and self-dismisses even if the cancels
        // below fail. Keyed via the owner map; falls back to primaryId's active session occurrence.
        if let ref = AlarmOwnerMap.ref(for: firedKey) {
            OccurrenceCompletionStore.markDone(owner: ref.ownerAlarmId, occurrence: ref.occurrenceKey)
        } else if let ref = AlarmOwnerMap.alarmKitIds(forOwner: primaryId).first.flatMap({ AlarmOwnerMap.ref(for: $0) }) {
            OccurrenceCompletionStore.markDone(owner: ref.ownerAlarmId, occurrence: ref.occurrenceKey)
        }

        // Mark the SESSION complete and PERSIST FIRST. From now on, any leftover backup that
        // fires reads this and self-dismisses — even if the best-effort cancels below fail.
        // This is what kills the double-mission / loop for good.
        let session = WakeSessionStore.session(forAlarmKitID: firedKey)
            ?? WakeSessionStore.activeSession(forAlarmId: primaryId)
        if let session { WakeSessionStore.markCompleted(sessionID: session.id) }
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

    // MARK: - Completion check

    /// PHASE 3: the authoritative "is this firing done?" check. Resolves the fired alarm to its
    /// owner+occurrence via the owner map, then checks the single completion checklist. Every
    /// backup of a firing resolves to the SAME key, so none can disagree with the primary —
    /// killing the "mission that won't go away". POSITIVE-ONLY (unknown/no ref → not done → the
    /// alarm rings), so it can never silence a fresh alarm.
    static func isOccurrenceDone(alarmKitId: String) -> Bool {
        guard let ref = AlarmOwnerMap.ref(for: alarmKitId) else { return false }
        return OccurrenceCompletionStore.isDone(owner: ref.ownerAlarmId, occurrence: ref.occurrenceKey)
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

        // Bridge: MainAppView reads these to present the typing mission with the word. (The
        // wake-up check is synthetic — not a saved alarm — so resolveFiring falls back to these.)
        UserDefaults.standard.set("Type Word", forKey: "alarmMission_\(checkId.uuidString)")
        UserDefaults.standard.set([word], forKey: "alarmItems_\(checkId.uuidString)")

        // PHASE 3: register it in the owner map (owner = itself) so its "done" check resolves
        // through the same single checklist as every other alarm.
        AlarmOwnerMap.register(
            alarmKitIds: [checkId.uuidString],
            owner: checkId.uuidString,
            occurrence: AlarmOwnerMap.occurrenceKey(for: fire)
        )

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

        // Rebuild from the user's saved alarms: primary + each alarm's own burst.
        for alarm in loadAlarms() where alarm.isEnabled {
            schedule(alarm)
        }
        refreshAllBursts()
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
        OccurrenceCompletionStore.prune()   // PHASE 3: keep the done-checklist from growing forever
        healFromTruth()
    }

    /// PHASE 4: self-heal against the source of truth (saved alarms + the live OS alarm list).
    /// For every alarm the OS still has scheduled, decide with the owner map whether it's still
    /// legitimate, and cancel it if not — so a kill-mid-edit self-corrects on the next open.
    ///
    /// FAILS SAFE (keeps alarms, never silences one): it only treats "owner is gone" as a real
    /// deletion when the saved-alarms list was read cleanly AND is non-empty. A failed/empty read
    /// must NEVER be mistaken for "everything was deleted" — that would wipe every backup and leave
    /// only primaries ("rings once, then never"). The two list-INDEPENDENT sweeps (a firing marked
    /// DONE, and a true ghost with no data) always run, since they can't misjudge on a bad read.
    private static func healFromTruth() {
        guard #available(iOS 26.1, *) else { return }
        let defaults = UserDefaults.standard

        // Read-safe: nil = unreadable, [] = genuinely none, [..] = real alarms. We only make the
        // DESTRUCTIVE "owner deleted" judgment when we have a trustworthy, non-empty list.
        let saved = loadAlarmsChecked()
        let canJudgeDeletion = (saved?.isEmpty == false)
        let enabledIds = Set((saved ?? []).filter { $0.isEnabled }.map { $0.id.uuidString })
        let ownerMap = AlarmOwnerMap.load()   // decode once, not per alarm

        for aid in AlarmService.shared.scheduledAlarmIds {
            let idStr = aid.uuidString

            // A live primary of an enabled saved alarm is always legit — never touch it.
            if enabledIds.contains(idStr) { continue }

            guard let ref = ownerMap[idStr] else {
                // Unknown to the owner map AND not an enabled primary. If it still has a mission
                // bridge it's a pre-migration alarm or a pending wake-up check — leave it to the
                // legacy sweep. Otherwise it's a ghost (its data was cleared) → cancel.
                if defaults.string(forKey: "alarmMission_\(idStr)") == nil {
                    AlarmService.shared.terminate(id: aid)
                }
                continue
            }

            let selfOwned = ref.ownerAlarmId == idStr        // e.g. a wake-up check owns itself
            // ownerGone is DESTRUCTIVE — gate it on a trustworthy, non-empty read (see doc above).
            let ownerGone = canJudgeDeletion && !selfOwned && !enabledIds.contains(ref.ownerAlarmId)
            let done = OccurrenceCompletionStore.isDone(owner: ref.ownerAlarmId, occurrence: ref.occurrenceKey)

            if done || ownerGone {
                AlarmService.shared.terminate(id: aid)
                defaults.removeObject(forKey: "alarmMission_\(idStr)")
                defaults.removeObject(forKey: "alarmItems_\(idStr)")
                defaults.removeObject(forKey: "alarmBackupPrimary_\(idStr)")
                AlarmOwnerMap.remove(alarmKitIds: [idStr])
            }
        }
    }

    // MARK: - Refresh (reconcile + per-alarm bursts)

    /// Cheap to call on app foreground / after any alarm change: sweep leftovers, then make sure
    /// EVERY enabled alarm has its own backup burst armed for its next fire. (AlarmKit comfortably
    /// holds 1500+ alarms — verified — so there's no need to ration bursts to a single alarm.)
    static func refresh() {
        // Keep the 6pm "tomorrow's alarms" reminder in sync with the current alarm list.
        if #available(iOS 16.0, *) {
            NotificationManager.shared.refreshTomorrowAlarmsReminder(alarms: loadAlarms())
        }
        guard #available(iOS 26.1, *) else { return }
        reconcile()
        refreshAllBursts()
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
    // while the mission is on screen, or after completion, is recognized and self-dismissed
    // (see MainAppView). Cleanup of leftovers is handled by reconcile() on every foreground.

    /// How long after its fire time a burst is treated as "actively firing" — during this window
    /// we won't tear it down/re-arm it, so a mid-mission kill still re-rings.
    private static let burstActiveWindow: TimeInterval = (backupOffsets.last ?? 2100) + 12 * 60

    /// Ensures EVERY enabled alarm has its own burst armed for its next fire. Per-alarm and
    /// independent — no global "soonest" coordination, so one alarm firing can never tear down
    /// another's (or its own) burst. Skips alarms already correctly armed, so a normal foreground
    /// with nothing changed does no work.
    static func refreshAllBursts() {
        guard #available(iOS 26.1, *) else { return }
        for alarm in loadAlarms() where alarm.isEnabled {
            ensureBurst(for: alarm)
        }
    }

    /// Arms `alarm`'s burst for its next fire, unless one is already armed for that occurrence or a
    /// burst is currently firing (which we must not disturb). Idempotent and cheap.
    private static func ensureBurst(for alarm: AlarmItem) {
        guard #available(iOS 26.1, *), let fire = nextFireDate(for: alarm) else { return }
        let owner = alarm.id.uuidString
        let now = Date()

        // Don't disturb THIS alarm's burst while it's actively firing (incomplete + within window).
        let firing = WakeSessionStore.allSessions().values.contains {
            $0.alarmId == owner && $0.completedAt == nil
            && now <= $0.validUntil
            && now >= $0.lastBackupFire.addingTimeInterval(-burstActiveWindow)
        }
        if firing { return }

        // Already armed for the current occurrence? Leave it (avoids churn on every open).
        let wantOccurrence = AlarmOwnerMap.occurrenceKey(for: fire)
        let armed = AlarmOwnerMap.load().contains {
            $0.key != owner && $0.value.ownerAlarmId == owner && $0.value.occurrenceKey == wantOccurrence
        }
        if armed { return }

        // No burst (or only a stale/spent one) → arm fresh (armBackups cancels stale ones first).
        Task { await armBackups(for: alarm, from: fire) }
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
