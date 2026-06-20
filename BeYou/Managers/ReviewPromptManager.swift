import Foundation

/// Decides when to surface the "Write a Review" sheet:
///  • the first alarm completion on each of the user's first 3 active days, then
///  • every 5th completion afterward — until they actually write a review.
///
/// `evaluate(...)` is called at each real alarm completion and raises a pending
/// flag; MainAppView shows the sheet when it sees the flag.
enum ReviewPromptManager {
    private static let hasWrittenKey = "hasWrittenReview"   // shared with MainAppView's @AppStorage
    private static let pendingKey = "pendingWriteReview"

    static var hasWritten: Bool {
        get { UserDefaults.standard.bool(forKey: hasWrittenKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasWrittenKey) }
    }

    static var isPending: Bool {
        get { UserDefaults.standard.bool(forKey: pendingKey) }
        set { UserDefaults.standard.set(newValue, forKey: pendingKey) }
    }

    /// Call once per real alarm completion.
    /// - Parameters:
    ///   - wasFirstToday: whether this completion was today's first.
    ///   - distinctDays: total distinct days the user has completed an alarm (incl. today).
    ///   - totalCompletions: running count of completed alarms.
    static func evaluate(wasFirstToday: Bool, distinctDays: Int, totalCompletions: Int) {
        guard !hasWritten else { return }

        let firstThreeDays = wasFirstToday && distinctDays <= 3
        let everyFifthAfter = distinctDays > 3 && totalCompletions % 5 == 0

        if firstThreeDays || everyFifthAfter {
            isPending = true
        }
    }

    /// User tapped "Write a Review" — stop prompting forever.
    static func markWritten() {
        hasWritten = true
        isPending = false
    }

    /// User dismissed the sheet without reviewing — clear this prompt; future
    /// completions can raise it again per the rules above.
    static func clearPending() {
        isPending = false
    }
}
