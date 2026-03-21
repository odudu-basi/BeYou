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

    func trackPaywallShown(placement: String) {
        track("Paywall Shown", properties: [
            "placement": placement
        ])
    }

    func trackSubscriptionPurchased() {
        track("Subscription Purchased")
    }

    func trackSubscriptionRestored() {
        track("Subscription Restored")
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
}
