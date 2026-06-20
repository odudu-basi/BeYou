import UIKit

/// Persists photos captured during alarm missions so they show up in the
/// Insights tab's "Morning memories" grid. Reads/writes the same
/// `morningMemories` UserDefaults key that InsightsView loads from.
enum MorningMemoryStore {
    static let key = "morningMemories"
    private static let maxMemories = 60

    /// Downscales + compresses the photo and stores it as the newest memory.
    static func add(image: UIImage, missionName: String) {
        let resized = image.resizedForMemory()
        guard let data = resized.jpegData(compressionQuality: 0.6) else { return }

        var memories = load()
        memories.insert(MorningMemory(imageData: data, date: Date(), missionName: missionName), at: 0)
        if memories.count > maxMemories {
            memories = Array(memories.prefix(maxMemories))
        }
        save(memories)
        AnalyticsManager.shared.trackMemorySaved(mission: missionName)
    }

    static func load() -> [MorningMemory] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MorningMemory].self, from: data) else {
            return []
        }
        return decoded
    }

    static func save(_ memories: [MorningMemory]) {
        if let encoded = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}

private extension UIImage {
    /// Shrinks large camera stills to a sensible size so UserDefaults stays small.
    func resizedForMemory(maxDimension: CGFloat = 1000) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
