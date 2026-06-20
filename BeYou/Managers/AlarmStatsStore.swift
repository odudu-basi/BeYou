import Foundation

/// One completed-alarm event, used to compute the Insights stat boxes.
struct AlarmCompletionRecord: Codable {
    let date: Date            // when the alarm was completed
    let wakeMinutes: Int      // minutes since midnight at wake-up (alarm fire time)
    let responseSeconds: Int  // alarm start → all missions complete
    let missions: [String]    // mission(s) used for this wake-up
    let sound: String         // alarm sound used
}

/// Records every alarm completion and derives the Insights stats:
/// average wake time, average response time, favourite mission, favourite sound.
enum AlarmStatsStore {
    private static let key = "alarmCompletionRecords"
    private static let maxRecords = 500

    // MARK: - Recording

    static func record(wakeDate: Date, responseSeconds: Int, missions: [String], sound: String) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: wakeDate)
        let wakeMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)

        var records = load()
        records.append(AlarmCompletionRecord(
            date: Date(),
            wakeMinutes: wakeMinutes,
            responseSeconds: max(0, responseSeconds),
            missions: missions,
            sound: sound
        ))
        if records.count > maxRecords {
            records = Array(records.suffix(maxRecords))
        }
        save(records)
    }

    static func load() -> [AlarmCompletionRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AlarmCompletionRecord].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func save(_ records: [AlarmCompletionRecord]) {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    // MARK: - Derived stats

    /// Average wake-up clock time in minutes-since-midnight, or nil if no data.
    static var averageWakeMinutes: Int? {
        let records = load()
        guard !records.isEmpty else { return nil }
        let total = records.reduce(0) { $0 + $1.wakeMinutes }
        return total / records.count
    }

    /// Average time (seconds) from alarm start to mission completion, or nil if no data.
    static var averageResponseSeconds: Int? {
        let records = load()
        guard !records.isEmpty else { return nil }
        let total = records.reduce(0) { $0 + $1.responseSeconds }
        return total / records.count
    }

    /// Most-used mission. Ties broken by earliest alphabetical name.
    static var favoriteMission: String? {
        var counts: [String: Int] = [:]
        for record in load() {
            for mission in record.missions {
                counts[mission, default: 0] += 1
            }
        }
        return mostFrequent(counts)
    }

    /// Most-used sound. Ties broken by earliest alphabetical name.
    static var favoriteSound: String? {
        var counts: [String: Int] = [:]
        for record in load() {
            counts[record.sound, default: 0] += 1
        }
        return mostFrequent(counts)
    }

    /// Highest count wins; on a tie, the alphabetically earliest key wins.
    private static func mostFrequent(_ counts: [String: Int]) -> String? {
        counts
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            .first?
            .key
    }
}
