import Foundation
import UserNotifications
import SwiftUI

@available(iOS 16.0, *)
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private let notificationCenter = UNUserNotificationCenter.current()

    // Notification Identifiers
    enum NotificationIdentifier: String {
        case disconnectWarning = "disconnect_warning"
        case appLimitWarning = "app_limit_warning"
        case sessionExpiry = "session_expiry"
        case streakUpdate = "streak_update"
        case midnightReset = "midnight_reset"
        case disciplineScore = "discipline_score"
        case dailyReminder = "daily_reminder"
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

    /// Notify user when their session is about to expire
    func scheduleSessionExpiryWarning(appName: String, expiryTime: Date) {
        guard isAuthorized else { return }

        let calendar = Calendar.current

        // Warning 1 minute before expiry
        if let warningTime = calendar.date(byAdding: .minute, value: -1, to: expiryTime),
           warningTime > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Session Ending Soon"
            content.body = "You have 1 minute left opening the app"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: warningTime.timeIntervalSinceNow,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: NotificationIdentifier.sessionExpiry.rawValue,
                content: content,
                trigger: trigger
            )

            notificationCenter.add(request) { error in
                if let error = error {
                    print("Failed to schedule session expiry: \(error)")
                }
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
