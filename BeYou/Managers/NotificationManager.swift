import Foundation
import UserNotifications
import SwiftUI
import Combine

@available(iOS 16.0, *)
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private let notificationCenter = UNUserNotificationCenter.current()

    // Notification Identifiers
    enum NotificationIdentifier: String {
        case disconnectWarning = "disconnect_warning"
        case appLimitWarning = "app_limit_warning"
        case streakUpdate = "streak_update"
        case midnightReset = "midnight_reset"
        case disciplineScore = "discipline_score"
        case dailyReminder = "daily_reminder"
        case affirmation = "affirmation"
    }

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Schedule Notifications

    /// Schedule notification 10 minutes before disconnect time starts
    func scheduleDisconnectWarning(type: String, startTime: Date) {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        var warningComponents = calendar.dateComponents([.hour, .minute], from: startTime)

        // Subtract 10 minutes
        if let warningDate = calendar.date(from: warningComponents),
           let adjustedDate = calendar.date(byAdding: .minute, value: -10, to: warningDate) {
            warningComponents = calendar.dateComponents([.hour, .minute], from: adjustedDate)
        }

        let content = UNMutableNotificationContent()
        content.title = "\(type) Focus Starts Soon"
        content.body = "Your \(type) disconnect time starts in 10 minutes"
        content.sound = .default
        content.badge = 1

        let trigger = UNCalendarNotificationTrigger(dateMatching: warningComponents, repeats: true)
        let identifier = "\(NotificationIdentifier.disconnectWarning.rawValue)_\(type.lowercased().replacingOccurrences(of: " ", with: "_"))"

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule disconnect warning: \(error)")
            }
        }
    }

    /// Show notification when user approaches app limit
    func scheduleAppLimitWarning(currentOpens: Int, limit: Int, appName: String) {
        guard isAuthorized, currentOpens >= limit - 2 else { return }

        let content = UNMutableNotificationContent()

        if currentOpens == limit - 2 {
            content.title = "Almost at Your Limit"
            content.body = "You've opened the app \(currentOpens)/\(limit) times today"
        } else if currentOpens == limit - 1 {
            content.title = "Last Chance"
            content.body = "One more open left for the app today"
        } else if currentOpens >= limit {
            content.title = "Daily Limit Reached"
            content.body = "You've reached your limit for the app today"
        }

        content.sound = .default
        content.badge = NSNumber(value: currentOpens)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(NotificationIdentifier.appLimitWarning.rawValue)_\(currentOpens)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule app limit warning: \(error)")
            }
        }
    }

    /// Daily streak update notification (sent at midnight)
    func scheduleStreakNotification(streakDays: Int, didMaintainStreak: Bool) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()

        if didMaintainStreak {
            if streakDays == 1 {
                content.title = "🔥 Streak Started!"
                content.body = "Great job! You stayed within your limit yesterday. Keep it going!"
            } else {
                content.title = "🔥 \(streakDays) Day Streak!"
                content.body = "Amazing! You've maintained your streak for \(streakDays) days"
            }
        } else {
            content.title = "Streak Reset"
            content.body = "You exceeded your limit yesterday. Start fresh today!"
        }

        content.sound = .default

        // Schedule for next midnight
        var dateComponents = DateComponents()
        dateComponents.hour = 0
        dateComponents.minute = 1

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.streakUpdate.rawValue,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule streak notification: \(error)")
            }
        }
    }

    /// Midnight reset notification
    func scheduleMidnightReset() {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Daily Reset"
        content.body = "Your app limits have been reset. Make today count!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 0
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.midnightReset.rawValue,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule midnight reset: \(error)")
            }
        }
    }

    /// Discipline score milestone notification
    func showDisciplineScoreUpdate(score: Int, change: Int) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()

        if change > 0 {
            content.title = "💪 Discipline Score +\(change)"
            content.body = "Your discipline score is now \(score). Keep making mindful choices!"
        } else if change < 0 {
            content.title = "Discipline Score \(change)"
            content.body = "Current score: \(score). You've got this!"
        }

        // Show milestone notifications
        if score == 75 {
            content.title = "🌟 75 Discipline Score!"
            content.body = "You're building incredible self-control. Keep going!"
        } else if score == 100 {
            content.title = "🏆 Perfect Score!"
            content.body = "Amazing! You've reached 100 discipline score!"
        }

        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(NotificationIdentifier.disciplineScore.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to show discipline score notification: \(error)")
            }
        }
    }

    /// Daily reminder to check in
    func scheduleDailyReminder() {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "How's Your Day Going?"
        content.body = "Check your progress and stay mindful of your goals"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 12 // Noon
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.dailyReminder.rawValue,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error)")
            }
        }
    }

    // MARK: - Affirmation Notifications

    /// Schedule affirmation notifications throughout the day at evenly spaced intervals.
    /// Uses the user's configured count, start time, and end time from onboarding.
    func scheduleAffirmationNotifications(
        count: Int,
        startTime: Date,
        endTime: Date,
        categories: [String] = [],
        goals: [String] = [],
        belief: String = "general",
        name: String = ""
    ) {
        guard isAuthorized, count > 0 else { return }

        // Cancel any existing affirmation notifications first
        cancelAffirmationNotifications()

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        // Convert to minutes since midnight for interval calculation
        let startMinutes = (startComponents.hour ?? 9) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 22) * 60 + (endComponents.minute ?? 0)

        // Handle case where end is after start
        let totalMinutes = endMinutes > startMinutes ? endMinutes - startMinutes : (24 * 60 - startMinutes) + endMinutes
        guard totalMinutes > 0 else { return }

        // Calculate interval between notifications
        let intervalMinutes = count > 1 ? totalMinutes / count : totalMinutes

        // Get personalized affirmations for notifications
        let affirmations = AffirmationService.shared.getDailyAffirmations(
            categories: categories,
            goals: goals,
            belief: belief,
            name: name,
            count: count
        )

        for i in 0..<count {
            let offsetMinutes = i * intervalMinutes
            let notificationMinute = (startMinutes + offsetMinutes) % (24 * 60)

            var dateComponents = DateComponents()
            dateComponents.hour = notificationMinute / 60
            dateComponents.minute = notificationMinute % 60

            let content = UNMutableNotificationContent()
            content.title = "Be You"

            // Use a personalized affirmation if available, otherwise use a default
            if i < affirmations.count {
                content.body = affirmations[i].text
            } else {
                content.body = "Take a moment to affirm yourself. You are worthy of everything good."
            }

            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let identifier = "\(NotificationIdentifier.affirmation.rawValue)_\(i)"

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            notificationCenter.add(request) { error in
                if let error = error {
                    print("Failed to schedule affirmation notification \(i): \(error)")
                }
            }
        }

        print("Scheduled \(count) affirmation notifications from \(startComponents.hour ?? 9):\(String(format: "%02d", startComponents.minute ?? 0)) to \(endComponents.hour ?? 22):\(String(format: "%02d", endComponents.minute ?? 0)) every \(intervalMinutes) minutes")
    }

    /// Reschedule affirmation notifications daily with fresh affirmations
    func rescheduleAffirmationsIfNeeded(onboardingData: OnboardingData) {
        guard let count = onboardingData.affirmationCount,
              let startTime = onboardingData.notifyStartTime,
              let endTime = onboardingData.notifyEndTime,
              count > 0 else { return }

        let belief = onboardingData.religion ?? "general"

        scheduleAffirmationNotifications(
            count: count,
            startTime: startTime,
            endTime: endTime,
            categories: onboardingData.categories,
            goals: onboardingData.goals,
            belief: belief,
            name: onboardingData.name ?? ""
        )
    }

    /// Cancel all affirmation notifications
    func cancelAffirmationNotifications() {
        let identifiers = (0..<20).map { "\(NotificationIdentifier.affirmation.rawValue)_\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Cancel Notifications

    func cancelNotification(identifier: NotificationIdentifier) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier.rawValue])
    }

    func cancelDisconnectWarning(type: String) {
        let identifier = "\(NotificationIdentifier.disconnectWarning.rawValue)_\(type.lowercased().replacingOccurrences(of: " ", with: "_"))"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
