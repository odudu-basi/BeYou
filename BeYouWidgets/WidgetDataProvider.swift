import Foundation

/// Reads shared data from App Groups for widgets
struct WidgetDataProvider {
    private static let appGroupIdentifier = "group.com.odudu.BeYou"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Discipline Score

    static func loadDisciplineScore() -> Int {
        // Force refresh from disk to avoid stale cached data
        sharedDefaults?.synchronize()
        guard let defaults = sharedDefaults, defaults.object(forKey: "disciplineScore") != nil else {
            return 100
        }
        return defaults.integer(forKey: "disciplineScore")
    }

    // MARK: - Onboarding Data (for affirmation personalization)

    static func loadOnboardingData() -> WidgetOnboardingData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "onboardingData"),
              let decoded = try? JSONDecoder().decode(WidgetOnboardingData.self, from: data) else {
            return WidgetOnboardingData()
        }
        return decoded
    }

    // MARK: - Affirmations

    static func loadAffirmations() -> [WidgetAffirmation] {
        // Try cached affirmations first (includes remote ones synced by main app)
        if let defaults = sharedDefaults,
           let data = defaults.data(forKey: "cachedAffirmations"),
           let decoded = try? JSONDecoder().decode([WidgetAffirmation].self, from: data),
           !decoded.isEmpty {
            return decoded
        }

        // Fall back to bundled JSON
        guard let url = Bundle.main.url(forResource: "affirmations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(WidgetAffirmationWrapper.self, from: data) else {
            return []
        }
        return wrapper.affirmations
    }

    /// Get a shuffled affirmation that changes every 15 minutes
    static func getAffirmation(for date: Date) -> String {
        let affirmations = loadAffirmations()
        guard !affirmations.isEmpty else { return "You are capable of amazing things." }

        let onboarding = loadOnboardingData()
        let name = onboarding.name ?? ""

        // Filter by user's belief
        let belief = onboarding.beliefs?.first ?? "general"
        let matched = affirmations.filter { aff in
            aff.beliefs.contains("general") || aff.beliefs.contains(belief)
        }

        let pool = matched.isEmpty ? affirmations : matched

        // Create a seed based on date + 15-minute interval
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let intervalIndex = (components.minute ?? 0) / 15
        let seed = (components.year ?? 2026) * 1000000
            + (components.month ?? 1) * 10000
            + (components.day ?? 1) * 100
            + (components.hour ?? 0) * 4
            + intervalIndex

        // Simple seeded random index
        var s = seed
        s = (s &* 16807) % 2147483647
        let index = abs(s) % pool.count

        var text = pool[index].text
        if name.isEmpty {
            text = text.replacingOccurrences(of: "{name}", with: "I")
        } else {
            text = text.replacingOccurrences(of: "{name}", with: name)
        }

        return text
    }
}

// MARK: - Lightweight Codable models for widget (avoid importing main app)

struct WidgetOnboardingData: Codable {
    var name: String?
    var categories: [String]?
    var beliefs: [String]?
    var goals: [String]?

    init() {
        name = nil
        categories = nil
        beliefs = nil
        goals = nil
    }

    // Accept unknown keys gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        categories = try container.decodeIfPresent([String].self, forKey: .categories)
        beliefs = try container.decodeIfPresent([String].self, forKey: .beliefs)
        goals = try container.decodeIfPresent([String].self, forKey: .goals)
    }

    enum CodingKeys: String, CodingKey {
        case name, categories, beliefs, goals
    }
}

struct WidgetAffirmation: Codable {
    let id: Int
    let text: String
    let categories: [String]
    let goals: [String]
    let beliefs: [String]
}

struct WidgetAffirmationWrapper: Codable {
    let affirmations: [WidgetAffirmation]
}

// MARK: - Widget Theme

struct WidgetTheme {
    let id: String
    let type: String // "solid", "gradient", "image"
    let background: String
    let gradientEnd: String?
    let textColor: String
    let accentColor: String
}

extension WidgetDataProvider {
    static func loadSelectedThemeId() -> String {
        sharedDefaults?.string(forKey: "selectedMotivationTheme") ?? "starry-mountains"
    }

    static func resolveTheme(id: String) -> WidgetTheme {
        let allThemes: [WidgetTheme] = [
            // Nature (image)
            WidgetTheme(id: "deep-forest", type: "image", background: "theme-deep-forest", gradientEnd: nil, textColor: "FFFFFF", accentColor: "7BB06A"),
            WidgetTheme(id: "alpine-lake", type: "image", background: "theme-alpine-lake", gradientEnd: nil, textColor: "FFFFFF", accentColor: "6EC4D8"),
            WidgetTheme(id: "golden-peaks", type: "image", background: "theme-golden-peaks", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D4A850"),
            WidgetTheme(id: "misty-summit", type: "image", background: "theme-misty-summit", gradientEnd: nil, textColor: "FFFFFF", accentColor: "A0B8C8"),
            WidgetTheme(id: "starry-mountains", type: "image", background: "theme-starry-mountains", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D4A060"),
            WidgetTheme(id: "arctic-night", type: "image", background: "theme-arctic-night", gradientEnd: nil, textColor: "FFFFFF", accentColor: "7AAAC0"),
            WidgetTheme(id: "northern-lights", type: "image", background: "theme-northern-lights", gradientEnd: nil, textColor: "FFFFFF", accentColor: "6CD8A0"),
            WidgetTheme(id: "forest-canopy", type: "image", background: "theme-forest-canopy", gradientEnd: nil, textColor: "FFFFFF", accentColor: "90D060"),
            WidgetTheme(id: "gentle-waves", type: "image", background: "theme-gentle-waves", gradientEnd: nil, textColor: "FFFFFF", accentColor: "80C0C8"),
            WidgetTheme(id: "enchanted-forest", type: "image", background: "theme-enchanted-forest", gradientEnd: nil, textColor: "FFFFFF", accentColor: "5890D0"),
            WidgetTheme(id: "golden-butterfly", type: "image", background: "theme-golden-butterfly", gradientEnd: nil, textColor: "FFFFFF", accentColor: "C8B040"),
            WidgetTheme(id: "golden-shore", type: "image", background: "theme-golden-shore", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D4A868"),
            WidgetTheme(id: "violet-sea", type: "image", background: "theme-violet-sea", gradientEnd: nil, textColor: "FFFFFF", accentColor: "B888D0"),
            WidgetTheme(id: "cloud-valley", type: "image", background: "theme-cloud-valley", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D8B888"),
            WidgetTheme(id: "ocean-gradient", type: "image", background: "theme-ocean-gradient", gradientEnd: nil, textColor: "FFFFFF", accentColor: "60B8B0"),
            WidgetTheme(id: "sunset-blaze", type: "image", background: "theme-sunset-blaze", gradientEnd: nil, textColor: "FFFFFF", accentColor: "E08850"),
            WidgetTheme(id: "pink-shores", type: "image", background: "theme-pink-shores", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D88098"),
            // Solid
            WidgetTheme(id: "desert-sand", type: "solid", background: "E8E0D4", gradientEnd: nil, textColor: "3D3A33", accentColor: "5C5647"),
            WidgetTheme(id: "midnight", type: "solid", background: "1A1A2E", gradientEnd: nil, textColor: "E0E0E0", accentColor: "8888AA"),
            WidgetTheme(id: "ocean-mist", type: "solid", background: "D4E8E0", gradientEnd: nil, textColor: "2E3D33", accentColor: "476056"),
            WidgetTheme(id: "lavender-dream", type: "solid", background: "E0D4E8", gradientEnd: nil, textColor: "3A2E3D", accentColor: "5C4768"),
            WidgetTheme(id: "warm-blush", type: "solid", background: "F2D9D5", gradientEnd: nil, textColor: "4A2F2B", accentColor: "8B5E57"),
            WidgetTheme(id: "forest-green", type: "solid", background: "2D4A3E", gradientEnd: nil, textColor: "D4E8DC", accentColor: "8BB89E"),
            WidgetTheme(id: "charcoal", type: "solid", background: "2A2A2A", gradientEnd: nil, textColor: "E8E8E8", accentColor: "888888"),
            WidgetTheme(id: "pure-white", type: "solid", background: "FFFFFF", gradientEnd: nil, textColor: "1A1A1A", accentColor: "666666"),
            WidgetTheme(id: "sage", type: "solid", background: "C5CDB0", gradientEnd: nil, textColor: "2E3325", accentColor: "5C6347"),
            // Gradient
            WidgetTheme(id: "sunrise", type: "gradient", background: "FFB88C", gradientEnd: "DE6262", textColor: "FFFFFF", accentColor: "8B5E3C"),
            WidgetTheme(id: "deep-ocean", type: "gradient", background: "1A3A5C", gradientEnd: "0F2744", textColor: "D4E0E8", accentColor: "6B8BA4"),
            WidgetTheme(id: "cotton-candy", type: "gradient", background: "E8D4E0", gradientEnd: "D4C4E8", textColor: "3D2E3A", accentColor: "7B5C6E"),
        ]

        return allThemes.first(where: { $0.id == id }) ?? allThemes[4] // default: starry-mountains
    }
}
