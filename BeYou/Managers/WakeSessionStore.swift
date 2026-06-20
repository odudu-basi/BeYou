import Foundation

/// One "firing" of an alarm. The primary alarm and ALL of its backups share a single
/// WakeSession. It's the one persisted source of truth: every alarm that fires looks up its
/// session and asks "is this mission already done / am I stale?" before doing anything — so we
/// never depend on AlarmKit's unreliable cancel to avoid the double-mission / loop.
///
/// A fresh session id is minted each time a burst is armed (per firing), which is also what
/// makes editing/reusing an alarm the same day work — it gets a new, not-completed session.
struct WakeSession: Codable {
    let id: String                  // fresh UUID per firing
    let alarmId: String             // the owning user alarm (UUID string)
    let primaryAlarmKitID: String   // the recurring/one-time primary → STOPPED, not cancelled
    var backupAlarmKitIDs: [String] // one-shot backups → safe to terminate
    var completedAt: Date?          // nil until the mission is finished
    var lastBackupFire: Date        // fire time of the latest backup (drives JIT extend)
    var validUntil: Date            // lastBackupFire + grace; past this the session is junk

    /// Every AlarmKit id that maps to this session (for the fire-time "am I done?" guard).
    var allAlarmKitIDs: [String] { [primaryAlarmKitID] + backupAlarmKitIDs }
}

/// Persisted store + reconciliation helpers for WakeSessions. Plain Foundation (not
/// availability-gated) so it can be touched from the scheduler, the views, and completion.
enum WakeSessionStore {
    private static let sessionsKey = "wakeSessions_v1"       // [sessionID: WakeSession]
    private static let mapKey      = "wakeAlarmToSession_v1" // [alarmKitID: sessionID]

    /// How long a completed session is kept so late-firing leftovers still resolve to
    /// "completed" and self-dismiss. After this it's pruned (its backups are long gone).
    static let completedKeepWindow: TimeInterval = 60 * 60   // 1 hour
    /// Grace past the last backup's fire time before the whole session is treated as junk.
    static let validGrace: TimeInterval = 12 * 60            // 12 minutes

    // MARK: - Raw load/save

    static func allSessions() -> [String: WakeSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([String: WakeSession].self, from: data) else { return [:] }
        return decoded
    }

    private static func saveSessions(_ sessions: [String: WakeSession]) {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    static func map() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mapKey) as? [String: String] ?? [:]
    }

    private static func saveMap(_ m: [String: String]) {
        UserDefaults.standard.set(m, forKey: mapKey)
    }

    // MARK: - Lookups

    static func session(id: String) -> WakeSession? { allSessions()[id] }

    /// The session that a given AlarmKit alarm (primary or backup) belongs to.
    static func session(forAlarmKitID alarmKitID: String) -> WakeSession? {
        guard let sid = map()[alarmKitID] else { return nil }
        return allSessions()[sid]
    }

    /// The newest not-yet-completed session for a user alarm (used when completing).
    static func activeSession(forAlarmId alarmId: String) -> WakeSession? {
        allSessions().values
            .filter { $0.alarmId == alarmId && $0.completedAt == nil }
            .sorted { $0.lastBackupFire > $1.lastBackupFire }
            .first
    }

    /// True only if the alarm's session exists AND its mission is already completed.
    static func isCompleted(alarmKitID: String) -> Bool {
        session(forAlarmKitID: alarmKitID)?.completedAt != nil
    }

    // MARK: - Mutations

    static func upsert(_ session: WakeSession) {
        var s = allSessions()
        s[session.id] = session
        saveSessions(s)
        // Tag every id of this session back to it.
        var m = map()
        for id in session.allAlarmKitIDs { m[id] = session.id }
        saveMap(m)
    }

    static func markCompleted(sessionID: String, at date: Date = Date()) {
        var s = allSessions()
        guard var session = s[sessionID] else { return }
        session.completedAt = date
        s[sessionID] = session
        saveSessions(s)
    }

    static func remove(sessionID: String) {
        var s = allSessions()
        s[sessionID] = nil
        saveSessions(s)
        saveMap(map().filter { $0.value != sessionID })
    }

    // MARK: - Reconciliation (Layers 3 & 4)

    /// Backup AlarmKit ids that should be cancelled now: anything belonging to a session whose
    /// mission is already completed, or whose validUntil has passed (orphan). The primary is
    /// never returned here — it's the persistent recurring alarm and is stopped separately.
    static func staleBackupIDs(now: Date = Date()) -> [String] {
        var ids: [String] = []
        for (_, session) in allSessions() where session.completedAt != nil || now > session.validUntil {
            ids.append(contentsOf: session.backupAlarmKitIDs)
        }
        return ids
    }

    /// Drops sessions that are safely done: completed more than an hour ago, or well past
    /// validUntil. Keeps recently-completed ones so late leftovers still self-dismiss.
    static func prune(now: Date = Date()) {
        var sessions = allSessions()
        var removed: [String] = []
        for (id, session) in sessions {
            let completedLongAgo = session.completedAt.map { now.timeIntervalSince($0) > completedKeepWindow } ?? false
            let expired = now > session.validUntil
            if completedLongAgo || expired {
                sessions[id] = nil
                removed.append(id)
            }
        }
        if !removed.isEmpty {
            saveSessions(sessions)
            saveMap(map().filter { !removed.contains($0.value) })
        }
    }
}
