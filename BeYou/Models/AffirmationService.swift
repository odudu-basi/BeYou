import Foundation

struct Affirmation: Identifiable, Codable {
    let id: Int
    let text: String
    let categories: [String]
    let goals: [String]
    let beliefs: [String]
}

class AffirmationService {
    static let shared = AffirmationService()

    private(set) var affirmations: [Affirmation]

    private let supabaseURL = "\(Secrets.supabaseURL)/rest/v1/affirmations?select=id,text,categories,goals,beliefs"
    private let supabaseKey = Secrets.supabaseAnonKey

    private let appGroupIdentifier = "group.com.odudu.BeYou"
    private let cacheKey = "cachedAffirmations"
    private let lastFetchKey = "lastAffirmationFetch"

    private init() {
        // Load bundled affirmations first (always available)
        var bundled: [Affirmation] = []
        if let url = Bundle.main.url(forResource: "affirmations", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AffirmationWrapper.self, from: data) {
            bundled = decoded.affirmations
        }

        // Check for cached (bundled + remote merged) affirmations
        if let cached = AffirmationService.loadCachedAffirmations(appGroup: appGroupIdentifier, key: cacheKey) {
            affirmations = cached
        } else {
            affirmations = bundled
        }
    }

    // MARK: - Remote Sync

    /// Fetch new affirmations from Supabase and merge with bundled ones.
    /// Call this on app launch. Silently fails if offline.
    func syncRemoteAffirmations() async {
        // Only fetch once per day
        if let lastFetch = UserDefaults(suiteName: appGroupIdentifier)?.object(forKey: lastFetchKey) as? Date,
           Calendar.current.isDateInToday(lastFetch) {
            return
        }

        guard let url = URL(string: supabaseURL) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("📡 AFFIRMATIONS: Supabase returned non-200")
                return
            }

            let remoteAffirmations = try JSONDecoder().decode([SupabaseAffirmation].self, from: data)
            print("📡 AFFIRMATIONS: Fetched \(remoteAffirmations.count) from Supabase")

            // Convert Supabase format to our Affirmation model
            let remote = remoteAffirmations.map { sa in
                Affirmation(
                    id: sa.id,
                    text: sa.text,
                    categories: sa.categories,
                    goals: sa.goals,
                    beliefs: sa.beliefs
                )
            }

            // Load bundled affirmations
            var bundled: [Affirmation] = []
            if let url = Bundle.main.url(forResource: "affirmations", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(AffirmationWrapper.self, from: data) {
                bundled = decoded.affirmations
            }

            // Merge: bundled first, then remote (skip duplicates by id)
            let bundledIds = Set(bundled.map { $0.id })
            let newRemote = remote.filter { !bundledIds.contains($0.id) }
            let merged = bundled + newRemote

            // Update in-memory
            await MainActor.run {
                self.affirmations = merged
            }

            // Cache to App Groups (accessible by widgets)
            saveCachedAffirmations(merged)

            // Mark fetch time
            UserDefaults(suiteName: appGroupIdentifier)?.set(Date(), forKey: lastFetchKey)
            UserDefaults(suiteName: appGroupIdentifier)?.synchronize()

            print("📡 AFFIRMATIONS: Merged total: \(merged.count) (bundled: \(bundled.count) + new remote: \(newRemote.count))")

        } catch {
            print("📡 AFFIRMATIONS: Sync failed (offline?): \(error.localizedDescription)")
        }
    }

    // MARK: - Cache

    private func saveCachedAffirmations(_ affirmations: [Affirmation]) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        if let encoded = try? JSONEncoder().encode(affirmations) {
            defaults.set(encoded, forKey: cacheKey)
            defaults.synchronize()
        }
    }

    static func loadCachedAffirmations(appGroup: String, key: String) -> [Affirmation]? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Affirmation].self, from: data) else {
            return nil
        }
        return decoded
    }

    // MARK: - Existing API (unchanged)

    /// Get personalized daily affirmations
    func getDailyAffirmations(
        categories: [String] = [],
        goals: [String] = [],
        belief: String = "general",
        name: String = "",
        count: Int = 5,
        offset: Int = 0
    ) -> [Affirmation] {
        let isReligious = belief != "general"

        let scored = affirmations.compactMap { affirmation -> (affirmation: Affirmation, score: Int)? in
            var score = 0

            let beliefMatch = affirmation.beliefs.contains("general") || affirmation.beliefs.contains(belief)
            guard beliefMatch else { return nil }

            let categoryMatches = affirmation.categories.filter { categories.contains($0) }.count
            score += categoryMatches * 2

            let goalMatches = affirmation.goals.filter { goals.contains($0) }.count
            score += goalMatches * 2

            return (affirmation, score)
        }

        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let daySeed = (today.year ?? 2026) * 10000 + (today.month ?? 1) * 100 + (today.day ?? 1)

        var shuffled = seededShuffle(scored, seed: daySeed)
        shuffled.sort { $0.score > $1.score }

        if offset > 0 {
            shuffled = Array(shuffled.dropFirst(offset))
        }

        if isReligious {
            let beliefSpecific = shuffled.filter { !$0.affirmation.beliefs.contains("general") }
            let general = shuffled.filter { $0.affirmation.beliefs.contains("general") }
            let maxBeliefCount = max(1, Int(ceil(Double(count) * 0.4)))
            let beliefPick = Array(beliefSpecific.prefix(maxBeliefCount))
            let generalPick = Array(general.prefix(count - beliefPick.count))
            var mixed: [(affirmation: Affirmation, score: Int)] = []
            var gIdx = 0, bIdx = 0
            for i in 0..<count {
                if bIdx < beliefPick.count && (beliefPick.count == 1 ? i == count / 2 : i % (count / max(1, beliefPick.count)) == (count / max(1, beliefPick.count)) / 2) {
                    mixed.append(beliefPick[bIdx])
                    bIdx += 1
                } else if gIdx < generalPick.count {
                    mixed.append(generalPick[gIdx])
                    gIdx += 1
                } else if bIdx < beliefPick.count {
                    mixed.append(beliefPick[bIdx])
                    bIdx += 1
                }
            }
            shuffled = mixed
        } else {
            shuffled = Array(shuffled.prefix(count))
        }

        return shuffled.map { item in
            let replaced = name.isEmpty
                ? item.affirmation.text.replacingOccurrences(of: "{name}", with: "I")
                : item.affirmation.text.replacingOccurrences(of: "{name}", with: name)
            return Affirmation(
                id: item.affirmation.id,
                text: replaced,
                categories: item.affirmation.categories,
                goals: item.affirmation.goals,
                beliefs: item.affirmation.beliefs
            )
        }
    }

    /// Get ALL matched affirmations (no count limit), shuffled daily
    func getAllMatchedAffirmations(
        categories: [String] = [],
        goals: [String] = [],
        belief: String = "general",
        name: String = ""
    ) -> [Affirmation] {
        let isReligious = belief != "general"

        let scored = affirmations.compactMap { affirmation -> (affirmation: Affirmation, score: Int)? in
            var score = 0
            let beliefMatch = affirmation.beliefs.contains("general") || affirmation.beliefs.contains(belief)
            guard beliefMatch else { return nil }

            let categoryMatches = affirmation.categories.filter { categories.contains($0) }.count
            score += categoryMatches * 2
            let goalMatches = affirmation.goals.filter { goals.contains($0) }.count
            score += goalMatches * 2

            return (affirmation, score)
        }

        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let daySeed = (today.year ?? 2026) * 10000 + (today.month ?? 1) * 100 + (today.day ?? 1)

        var shuffled = seededShuffle(scored, seed: daySeed)
        shuffled.sort { $0.score > $1.score }

        if isReligious {
            let beliefSpecific = shuffled.filter { !$0.affirmation.beliefs.contains("general") }
            let general = shuffled.filter { $0.affirmation.beliefs.contains("general") }
            let total = shuffled.count
            let maxBeliefCount = max(1, Int(ceil(Double(total) * 0.4)))
            let beliefPick = Array(beliefSpecific.prefix(maxBeliefCount))
            let generalPick = Array(general)
            var mixed: [(affirmation: Affirmation, score: Int)] = []
            var gIdx = 0, bIdx = 0
            let totalMixed = generalPick.count + beliefPick.count
            let interval = beliefPick.count > 0 ? max(2, totalMixed / beliefPick.count) : totalMixed + 1
            for i in 0..<totalMixed {
                if bIdx < beliefPick.count && i > 0 && i % interval == interval / 2 {
                    mixed.append(beliefPick[bIdx])
                    bIdx += 1
                } else if gIdx < generalPick.count {
                    mixed.append(generalPick[gIdx])
                    gIdx += 1
                } else if bIdx < beliefPick.count {
                    mixed.append(beliefPick[bIdx])
                    bIdx += 1
                }
            }
            shuffled = mixed
        }

        return shuffled.map { item in
            let replaced = name.isEmpty
                ? item.affirmation.text.replacingOccurrences(of: "{name}", with: "I")
                : item.affirmation.text.replacingOccurrences(of: "{name}", with: name)
            return Affirmation(
                id: item.affirmation.id,
                text: replaced,
                categories: item.affirmation.categories,
                goals: item.affirmation.goals,
                beliefs: item.affirmation.beliefs
            )
        }
    }

    /// Get a single affirmation of the day
    func getAffirmationOfTheDay(
        categories: [String] = [],
        goals: [String] = [],
        belief: String = "general",
        name: String = ""
    ) -> Affirmation? {
        getDailyAffirmations(categories: categories, goals: goals, belief: belief, name: name, count: 1).first
    }

    /// Get all affirmations for a category
    func getByCategory(_ category: String, name: String = "") -> [Affirmation] {
        affirmations
            .filter { $0.categories.contains(category) }
            .map { affirmation in
                let replaced = name.isEmpty
                    ? affirmation.text.replacingOccurrences(of: "{name}", with: "I")
                    : affirmation.text.replacingOccurrences(of: "{name}", with: name)
                return Affirmation(
                    id: affirmation.id,
                    text: replaced,
                    categories: affirmation.categories,
                    goals: affirmation.goals,
                    beliefs: affirmation.beliefs
                )
            }
    }

    /// Get all unique categories
    var allCategories: [String] {
        let cats: [String] = [
            "Anxiety", "Morning", "Feeling sassy", "Self-love", "Overthinking",
            "Attraction", "Gratitude", "Purpose", "Dream big", "Confidence",
            "Self-talk", "Positivity", "Romance", "Inner child"
        ]
        return cats
    }

    /// Total count
    var totalCount: Int { affirmations.count }

    // MARK: - Private

    private func seededShuffle<T>(_ array: [(affirmation: T, score: Int)], seed: Int) -> [(affirmation: T, score: Int)] {
        var arr = array
        var s = seed
        for i in stride(from: arr.count - 1, through: 1, by: -1) {
            s = (s &* 16807) % 2147483647
            let j = abs(s) % (i + 1)
            arr.swapAt(i, j)
        }
        return arr
    }
}

// MARK: - Codable Models

private struct AffirmationWrapper: Codable {
    let affirmations: [Affirmation]
}

/// Supabase returns arrays as PostgreSQL arrays, which decode as regular Swift arrays
private struct SupabaseAffirmation: Codable {
    let id: Int
    let text: String
    let categories: [String]
    let goals: [String]
    let beliefs: [String]
}
