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
    private static let pendingNativeKey = "pendingNativeReview"

    static var hasWritten: Bool {
        get { UserDefaults.standard.bool(forKey: hasWrittenKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasWrittenKey) }
    }

    /// Raised for the CUSTOM "Write a Review" sheet (days 2–3 first-completion, every 5th after).
    static var isPending: Bool {
        get { UserDefaults.standard.bool(forKey: pendingKey) }
        set { UserDefaults.standard.set(newValue, forKey: pendingKey) }
    }

    /// Raised for APPLE'S NATIVE rating prompt — used on the user's very first completion.
    static var pendingNativeReview: Bool {
        get { UserDefaults.standard.bool(forKey: pendingNativeKey) }
        set { UserDefaults.standard.set(newValue, forKey: pendingNativeKey) }
    }

    /// Call once per real alarm completion.
    /// - Parameters:
    ///   - wasFirstToday: whether this completion was today's first.
    ///   - distinctDays: total distinct days the user has completed an alarm (incl. today).
    ///   - totalCompletions: running count of completed alarms.
    static func evaluate(wasFirstToday: Bool, distinctDays: Int, totalCompletions: Int) {
        guard !hasWritten else { return }

        // Very first completion → Apple's native rating prompt (not the custom sheet).
        if totalCompletions == 1 {
            pendingNativeReview = true
            return
        }

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
