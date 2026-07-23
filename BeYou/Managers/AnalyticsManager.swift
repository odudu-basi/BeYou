import Foundation
import Mixpanel
import MixpanelSessionReplay

@available(iOS 16.0, *)
class AnalyticsManager {
    static let shared = AnalyticsManager()
    private let token = Secrets.mixpanelToken

    private init() {}

    // MARK: - Configuration

    func configure() {
        Mixpanel.initialize(
            token: token,
            trackAutomaticEvents: true
        )

        Mixpanel.mainInstance().loggingEnabled = false

        // Initialize Session Replay separately
        let replayConfig = MPSessionReplayConfig(wifiOnly: false)
        MPSessionReplay.initialize(
            token: Mixpanel.mainInstance().apiToken,
            distinctId: Mixpanel.mainInstance().distinctId,
            config: replayConfig
        )

        registerSuperProperties()

        print("📊 ANALYTICS: Mixpanel initialized with Session Replay")
    }

    /// Identify user (call after onboarding when we have a name, or on login)
    func identify(userId: String, name: String? = nil) {
        Mixpanel.mainInstance().identify(distinctId: userId)
        if let name = name {
            Mixpanel.mainInstance().people.set(properties: ["$name": name])
        }
        print("📊 ANALYTICS: Identified user \(userId)")
    }

    /// Set user properties (e.g., after onboarding)
    func setUserProperties(_ properties: [String: MixpanelType]) {
        Mixpanel.mainInstance().people.set(properties: properties)
    }

    // MARK: - Track Events

    func track(_ event: String, properties: [String: MixpanelType]? = nil) {
        Mixpanel.mainInstance().track(event: event, properties: properties)
        print("📊 ANALYTICS: Tracked '\(event)'")
    }

    // MARK: - Onboarding Events

    func trackOnboardingStarted() {
        track("Onboarding Started")
    }

    func trackOnboardingCompleted(data: OnboardingData) {
        track("Onboarding Completed", properties: [
            "goals_count": data.goals.count,
            "categories_count": data.categories.count,
            "has_religion": (data.religion == "yes") as MixpanelType,
            "current_screen_time": (data.currentScreenTime ?? 0) as MixpanelType,
            "goal_time": (data.goalTime ?? 0) as MixpanelType
        ] as [String: MixpanelType])

        // Set user profile properties from onboarding
        var props: [String: MixpanelType] = [:]
        if let name = data.name { props["name"] = name }
        if let gender = data.gender { props["gender"] = gender }
        if let age = data.age { props["age"] = age }
        props["goals"] = data.goals as MixpanelType
        props["categories"] = data.categories as MixpanelType
        if !props.isEmpty { setUserProperties(props) }
    }

    // MARK: - Subscription Events

    func trackPaywallShown(placement: String, source: String? = nil) {
        var props: [String: MixpanelType] = ["placement": placement]
        if let source { props["source"] = source }
        track("Paywall Shown", properties: props)
    }

    func trackSubscriptionPurchased() {
        track("Subscription Purchased")
    }

    func trackSubscriptionRestored() {
        track("Subscription Restored")
    }

    func trackCancellationReason(reason: String, details: String) {
        track("Subscription Cancel Reason", properties: [
            "reason": reason,
            "details": details,
            "has_details": !details.isEmpty
        ])
        // Also store on the user profile so you can see it on the person record.
        setUserProperties([
            "last_cancel_reason": reason,
            "last_cancel_details": details
        ])
    }

    // MARK: - App Intention Events

    func trackAppIntentionCreated(appName: String, timesPerDay: Int, minutesPerSession: Int) {
        track("App Intention Created", properties: [
            "app_name": appName,
            "times_per_day": timesPerDay,
            "minutes_per_session": minutesPerSession
        ])
    }

    func trackAppIntentionDeleted(appName: String) {
        track("App Intention Deleted", properties: [
            "app_name": appName
        ])
    }

    // MARK: - Shield / Intervention Events

    func trackShieldContinuePressed(appName: String) {
        track("Shield Continue Pressed", properties: [
            "app_name": appName
        ])
    }

    func trackShieldNevermindPressed(appName: String) {
        track("Shield Nevermind Pressed", properties: [
            "app_name": appName
        ])
    }

    func trackInterventionCompleted(appName: String, unlockDuration: Int) {
        track("Intervention Completed", properties: [
            "app_name": appName,
            "unlock_duration_minutes": unlockDuration
        ])
    }

    func trackBreakthroughRecorded(appName: String, totalToday: Int) {
        track("Breakthrough Recorded", properties: [
            "app_name": appName,
            "total_today": totalToday
        ])
    }

    func trackNevermindRecorded() {
        track("Nevermind Recorded")
    }

    // MARK: - Schedule Events

    func trackScheduleCreated(name: String, startTime: String, endTime: String, appsCount: Int) {
        track("Schedule Created", properties: [
            "schedule_name": name,
            "start_time": startTime,
            "end_time": endTime,
            "apps_count": appsCount
        ])
    }

    func trackScheduleDeleted(name: String) {
        track("Schedule Deleted", properties: [
            "schedule_name": name
        ])
    }

    func trackScheduleToggled(name: String, isEnabled: Bool) {
        track("Schedule Toggled", properties: [
            "schedule_name": name,
            "is_enabled": isEnabled
        ])
    }

    // MARK: - Challenge Events

    func trackChallengeCreated(name: String, affectsDiscipline: Bool) {
        track("Challenge Created", properties: [
            "challenge_name": name,
            "affects_discipline": affectsDiscipline
        ])
    }

    func trackChallengeCompleted(name: String) {
        track("Challenge Completed", properties: [
            "challenge_name": name
        ])
    }

    // MARK: - Engagement Events

    func trackAppOpened() {
        track("App Opened")
    }

    func trackDisciplineScoreChanged(oldScore: Int, newScore: Int) {
        track("Discipline Score Changed", properties: [
            "old_score": oldScore,
            "new_score": newScore,
            "change": newScore - oldScore
        ])
    }

    // MARK: - Foundations

    /// Super properties are attached to every event. Call once at launch.
    func registerSuperProperties() {
        var props: [String: MixpanelType] = [:]
        props["is_pro"] = SubscriptionManager.shared.isProUser
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            props["app_version"] = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            props["build"] = build
        }
        Mixpanel.mainInstance().registerSuperProperties(props)
    }

    func setSuperProperty(_ key: String, _ value: MixpanelType) {
        Mixpanel.mainInstance().registerSuperProperties([key: value])
    }

    /// Pushes the latest wake-up stats onto the user profile (call after a completion).
    func syncWakeUpStats() {
        var props: [String: MixpanelType] = [
            "current_streak": AlarmCompletionStore.currentStreak(),
            "total_wakeups": UserDefaults.standard.integer(forKey: "totalWakeUps")
        ]
        if let m = AlarmStatsStore.averageWakeMinutes { props["avg_wake_minutes"] = m }
        if let s = AlarmStatsStore.averageResponseSeconds { props["avg_response_seconds"] = s }
        if let fm = AlarmStatsStore.favoriteMission { props["favorite_mission"] = fm }
        if let fs = AlarmStatsStore.favoriteSound { props["favorite_sound"] = fs }
        setUserProperties(props)
    }

    // MARK: - Alarm Lifecycle

    private func alarmProps(_ alarm: AlarmItem) -> [String: MixpanelType] {
        var p: [String: MixpanelType] = [
            "time": alarm.timeOnly,
            "is_scheduled": alarm.isScheduled,
            "repeat_days_count": alarm.repeatDays.count,
            "mission_count": alarm.missionList.count,
            "sound": alarm.sound
        ]
        p["missions"] = alarm.missionList as MixpanelType
        return p
    }

    func trackAlarmCreated(_ alarm: AlarmItem) {
        track("Alarm Created", properties: alarmProps(alarm))
    }

    func trackAlarmEdited(_ alarm: AlarmItem, field: String? = nil) {
        var p = alarmProps(alarm)
        if let field { p["field_changed"] = field }
        track("Alarm Edited", properties: p)
    }

    func trackAlarmDeleted(_ alarm: AlarmItem, source: String) {
        var p = alarmProps(alarm)
        p["source"] = source
        track("Alarm Deleted", properties: p)
    }

    func trackAlarmToggled(_ alarm: AlarmItem, enabled: Bool) {
        var p = alarmProps(alarm)
        p["enabled"] = enabled
        track("Alarm Toggled", properties: p)
    }

    // MARK: - Wake-up Loop

    func trackAlarmFired(alarmId: UUID, missions: [String]) {
        track("Alarm Fired", properties: [
            "alarm_id": alarmId.uuidString,
            "missions": missions as MixpanelType,
            "mission_count": missions.count
        ])
    }

    func trackMissionStarted(mission: String, index: Int, ofCount: Int) {
        track("Mission Started", properties: [
            "mission": mission,
            "index": index,
            "of_count": ofCount
        ])
    }

    func trackMissionCompleted(mission: String, secondsTaken: Int) {
        track("Mission Completed", properties: [
            "mission": mission,
            "seconds_taken": secondsTaken
        ])
    }

    func trackAlarmCompleted(wakeTime: String, secondsTaken: Int, missions: [String], sound: String, streak: Int) {
        track("Alarm Completed", properties: [
            "wake_time": wakeTime,
            "time_to_complete_seconds": secondsTaken,
            "missions": missions as MixpanelType,
            "mission_count": missions.count,
            "sound": sound,
            "streak": streak
        ])
    }

    // MARK: - Permissions

    func trackPermissionResult(type: String, granted: Bool) {
        track("Permission Result", properties: [
            "type": type,
            "granted": granted
        ])
    }

    // MARK: - Paywall

    func trackPaywallDismissed(placement: String, result: String, source: String? = nil) {
        var props: [String: MixpanelType] = [
            "placement": placement,
            "result": result
        ]
        if let source { props["source"] = source }
        track("Paywall Dismissed", properties: props)
    }

    // MARK: - Engagement (P1)

    func trackAffirmationDetailOpened(categories: [String]) {
        track("Affirmation Detail Opened", properties: ["categories": categories as MixpanelType])
    }

    func trackThemeChanged(themeId: String) {
        track("Theme Changed", properties: ["theme_id": themeId])
    }

    func trackAffirmationCategoryChanged(categories: [String]) {
        track("Affirmation Category Changed", properties: [
            "categories": categories as MixpanelType,
            "count": categories.count
        ])
    }

    func trackAffirmationFavorited(favorited: Bool) {
        track("Affirmation Favorited", properties: ["favorited": favorited])
    }

    func trackAffirmationShared() {
        track("Affirmation Shared")
    }

    func trackMeditateTapped(source: String) {
        track("Meditate Tapped", properties: ["source": source])
    }

    func trackMemorySaved(mission: String) {
        track("Memory Saved", properties: ["mission": mission])
    }

    func trackMemoryViewed(mission: String) {
        track("Memory Viewed", properties: ["mission": mission])
    }

    func trackMemoryDeleted(mission: String) {
        track("Memory Deleted", properties: ["mission": mission])
    }

    func trackMemoriesCleared(count: Int) {
        track("Memories Cleared", properties: ["count": count])
    }

    func trackInsightsViewed() {
        track("Insights Viewed")
    }

    func trackStreakCalendarOpened() {
        track("Streak Calendar Opened")
    }
}
