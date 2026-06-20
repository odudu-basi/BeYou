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
        case streakWarning = "streak_warning"
        case tomorrowAlarms = "tomorrow_alarms"
        case dailyEncouragement = "daily_encouragement"
    }

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let wasUndetermined = await notificationCenter.notificationSettings().authorizationStatus == .notDetermined
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
                if wasUndetermined {
                    AnalyticsManager.shared.trackPermissionResult(type: "notifications", granted: granted)
                }
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

    /// Warn user they're about to lose their streak if they have no active intentions
    func scheduleStreakWarningNotification(currentStreak: Int) {
        guard isAuthorized, currentStreak > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔥 Your \(currentStreak) day streak is at risk!"
        content.body = "Add an app intention to keep your streak alive before midnight."
        content.sound = .default

        // Schedule for 9 PM today
        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.streakWarning.rawValue,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule streak warning: \(error)")
            }
        }
    }

    /// Cancel streak warning (user added an intention)
    func cancelStreakWarningNotification() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [NotificationIdentifier.streakWarning.rawValue]
        )
    }

    /// Midnight reset notification

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

    // MARK: - Tomorrow's Alarms Reminder (6pm the day before)

    /// Schedules a 6pm reminder listing the alarms set for the next day. Re-computed each
    /// time it's called (alarm changes / app foreground) so the body stays accurate.
    func refreshTomorrowAlarmsReminder(alarms: [AlarmItem]) {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [NotificationIdentifier.tomorrowAlarms.rawValue]
        )

        let cal = Calendar.current
        let now = Date()
        guard var sixPM = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now) else { return }
        if sixPM <= now {
            sixPM = cal.date(byAdding: .day, value: 1, to: sixPM) ?? sixPM
        }
        // The "next day" relative to that 6pm.
        guard let targetDay = cal.date(byAdding: .day, value: 1, to: sixPM) else { return }

        // Only the first (earliest) alarm of the next day.
        let firstAlarm = alarms
            .filter { $0.isEnabled && Self.alarm($0, fires: targetDay) }
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
            .first

        guard let firstAlarm else { return } // nothing tomorrow → no reminder

        let content = UNMutableNotificationContent()
        content.title = "Tomorrow's wake-up 🌙"
        content.body = "Your first alarm is at \(firstAlarm.formattedTime). Get some rest."
        content.sound = .default

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: sixPM)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.tomorrowAlarms.rawValue,
            content: content,
            trigger: trigger
        )
        notificationCenter.add(request) { error in
            if let error = error { print("Failed to schedule tomorrow reminder: \(error)") }
        }
    }

    /// Whether an alarm will fire on the given calendar day.
    private static func alarm(_ alarm: AlarmItem, fires date: Date) -> Bool {
        let cal = Calendar.current
        let isOneTime = !alarm.isScheduled || alarm.repeatDays.isEmpty
        if isOneTime {
            guard let fire = AlarmScheduler.nextFireDate(for: alarm) else { return false }
            return cal.isDate(fire, inSameDayAs: date)
        } else {
            let weekday = cal.component(.weekday, from: date) // 1=Sun...7=Sat
            let index = (weekday + 5) % 7                     // -> Mon=0...Sun=6
            return alarm.repeatDays.contains(index)
        }
    }

    // MARK: - Daily Encouragement (after the first mission of the day)

    private let encouragements = [
        "Have an amazing day — be the best version of yourself ✨",
        "You showed up for yourself today. Now go be great 💪",
        "Day started right. Make it yours 🌟",
        "You're already winning today. Keep that energy 🔥",
        "Be present, be kind, be you. Have a great day ☀️"
    ]

    /// Sends one positive message after the first completed mission of the day. Guarded so
    /// it fires at most once per calendar day.
    func sendDailyEncouragement() {
        let key = "lastEncouragementDay"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)

        let content = UNMutableNotificationContent()
        content.title = "Good morning ☀️"
        content.body = encouragements.randomElement() ?? "Have a great day — be the best version of yourself ✨"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(NotificationIdentifier.dailyEncouragement.rawValue)_\(today)",
            content: content,
            trigger: trigger
        )
        notificationCenter.add(request) { error in
            if let error = error { print("Failed to schedule encouragement: \(error)") }
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

    // MARK: - Meditation Notifications

    func scheduleMeditationNotifications(times: [MeditationTime]) {
        // Remove old meditation notifications
        notificationCenter.getPendingNotificationRequests { requests in
            let meditationIds = requests.filter { $0.identifier.hasPrefix("meditation_") }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: meditationIds)
        }

        for time in times {
            for day in time.days {
                var dateComponents = DateComponents()
                dateComponents.hour = time.hour
                dateComponents.minute = time.minute
                dateComponents.weekday = day

                let content = UNMutableNotificationContent()
                content.title = "Time to Meditate"
                content.body = "It's time for \(time.name). Take a moment to breathe and reflect."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let identifier = "meditation_\(time.id.uuidString)_\(day)"

                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                notificationCenter.add(request)
            }
        }
    }

    func cancelMeditationNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            let meditationIds = requests.filter { $0.identifier.hasPrefix("meditation_") }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: meditationIds)
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
