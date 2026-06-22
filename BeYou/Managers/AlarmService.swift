import Foundation
import Combine
import SwiftUI
import AlarmKit
import AppIntents
import ActivityKit

@available(iOS 26.1, *)
struct BeYouAlarmMetadata: AlarmMetadata {
    var alarmName: String
    var missionType: String
    var selectedItems: [String]
}

@available(iOS 26.1, *)
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open BeYou"
    static var description: IntentDescription = "Open BeYou to complete your mission"
    // Route "slide to stop" through the app instead of silently dismissing the alarm,
    // so the user still has to complete the mission.
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Alarm ID", default: "")
    var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        // Mark the mission as still owed; MainAppView reads this on launch and presents it.
        UserDefaults.standard.set(alarmID, forKey: "pendingMissionAlarmID")
        return .result()
    }
}

@available(iOS 26.1, *)
struct OpenMissionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Mission"
    static var description: IntentDescription = "Open BeYou to complete your mission"
    // The orange button opens the app to do the mission (without stopping the alarm).
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Alarm ID", default: "")
    var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(alarmID, forKey: "pendingMissionAlarmID")
        return .result()
    }
}

@available(iOS 26.1, *)
class AlarmService: ObservableObject {
    static let shared = AlarmService()

    @Published var alarms: [Alarm] = []
    @Published var authorizationState: AlarmManager.AuthorizationState = .notDetermined
    @Published var currentAlertingAlarmId: Alarm.ID?

    private let manager = AlarmManager.shared

    private init() {
        authorizationState = manager.authorizationState
        loadAlarms()
        observeAlarms()
        observeAuth()
    }

    /// Whether AlarmKit authorization has been granted.
    var isAuthorized: Bool {
        authorizationState == .authorized
    }

    /// Maps a UI sound name to a bundled AlarmKit sound. Custom files live in the app
    /// bundle as .caf (alarm_*.caf); anything unmapped falls back to the system default.
    static func alertSound(for name: String) -> AlertConfiguration.AlertSound {
        switch name {
        case "Annoying":    return .named("alarm_annoying.caf")
        case "Beeping":     return .named("alarm_beeping.caf")
        case "Zen":         return .named("alarm_zen.caf")
        case "Nature":      return .named("Animals in nature.caf")
        case "Rooster":     return .named("rooster.caf")
        case "Kalimba":     return .named("kalimba.caf")
        case "Guitar":      return .named("Guitar.caf")
        case "Jazz":        return .named("Jazz.caf")
        case "Lofi Piano":  return .named("Lofi Piano.caf")
        case "Melodic":     return .named("Melodic.caf")
        case "Loud Bell":   return .named("Loud bell.caf")
        case "Buzzer":      return .named("loud buzzer.caf")
        case "Loud Impact": return .named("Loud impact alarm.caf")
        case "Fighter Jet": return .named("Fighter jet.caf")
        case "Navy":        return .named("Navy loud.caf")
        case "Raid":        return .named("Raid.caf")
        default:            return .default
        }
    }

    func requestAuthorization() async -> Bool {
        let previous = await MainActor.run { authorizationState }
        do {
            let state = try await manager.requestAuthorization()
            await MainActor.run {
                authorizationState = state
                if previous == .notDetermined {
                    AnalyticsManager.shared.trackPermissionResult(type: "alarm", granted: state == .authorized)
                }
            }
            return state == .authorized
        } catch {
            return false
        }
    }

    func scheduleAlarm(
        id: UUID,
        hour: Int,
        minute: Int,
        repeatDays: Set<Int>,
        name: String,
        missionType: String,
        selectedItems: [String],
        sound: AlertConfiguration.AlertSound = .default
    ) async throws -> Alarm {
        let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)

        let recurrence: Alarm.Schedule.Relative.Recurrence
        if repeatDays.isEmpty {
            recurrence = .never
        } else {
            let weekdays: [Locale.Weekday] = repeatDays.sorted().compactMap { indexToWeekday($0) }
            recurrence = .weekly(weekdays)
        }

        let schedule = Alarm.Schedule.relative(
            Alarm.Schedule.Relative(time: time, repeats: recurrence)
        )

        return try await scheduleConfigured(
            id: id,
            schedule: schedule,
            name: name,
            missionType: missionType,
            selectedItems: selectedItems,
            sound: sound
        )
    }

    /// Schedules a one-time alarm at an exact date. Used for backup alarms that re-ring
    /// shortly after the primary, so the user can't escape by killing the app.
    func scheduleOneShot(
        id: UUID,
        date: Date,
        name: String,
        missionType: String,
        sound: AlertConfiguration.AlertSound = .default
    ) async throws {
        _ = try await scheduleConfigured(
            id: id,
            schedule: Alarm.Schedule.fixed(date),
            name: name,
            missionType: missionType,
            selectedItems: [],
            sound: sound
        )
    }

    private func scheduleConfigured(
        id: UUID,
        schedule: Alarm.Schedule,
        name: String,
        missionType: String,
        selectedItems: [String],
        sound: AlertConfiguration.AlertSound
    ) async throws -> Alarm {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: name),
            secondaryButton: AlarmButton(
                text: LocalizedStringResource(stringLiteral: missionType),
                textColor: .white,
                systemImageName: "camera.viewfinder"
            ),
            secondaryButtonBehavior: .custom
        )

        let presentation = AlarmPresentation(alert: alert)

        let metadata = BeYouAlarmMetadata(
            alarmName: name,
            missionType: missionType,
            selectedItems: selectedItems
        )

        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: .orange
        )

        let config = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: id.uuidString),
            secondaryIntent: OpenMissionIntent(alarmID: id.uuidString),
            sound: sound
        )

        let alarm = try await manager.schedule(id: id, configuration: config)
        loadAlarms()
        return alarm
    }

    /// Terminates every scheduled/alerting alarm and returns their id strings (so the caller
    /// can clear matching bridge bookkeeping). Used by the one-time migration wipe.
    func terminateAll() -> [String] {
        let ids = alarms.map { $0.id }
        for id in ids { terminate(id: id) }
        return ids.map { $0.uuidString }
    }

    /// All alarm ids currently scheduled with iOS, read fresh (used by the ghost sweep).
    func currentAlarmIDs() -> [String] {
        ((try? manager.alarms) ?? []).map { $0.id.uuidString }
    }

    func stopAlarm(id: Alarm.ID) {
        do {
            try manager.stop(id: id)
            currentAlertingAlarmId = nil
            loadAlarms()
        } catch {
            print("Failed to stop alarm: \(error)")
        }
    }

    func cancelAlarm(id: Alarm.ID) {
        do {
            try manager.cancel(id: id)
            loadAlarms()
        } catch {
            print("Failed to cancel alarm: \(error)")
        }
    }

    /// Fully terminates an alarm regardless of its state: `stop` handles one that's
    /// currently ringing, `cancel` handles one that's still scheduled. Either call can
    /// throw harmlessly depending on the alarm's state, so both are best-effort.
    func terminate(id: Alarm.ID) {
        do { try manager.stop(id: id) } catch {}
        do { try manager.cancel(id: id) } catch {}
        loadAlarms()
    }

    func loadAlarms() {
        do {
            alarms = try manager.alarms
            currentAlertingAlarmId = alarms.first(where: { $0.state == .alerting })?.id
        } catch {
            print("Failed to load alarms: \(error)")
        }
    }

    private func observeAlarms() {
        Task {
            for await updatedAlarms in manager.alarmUpdates {
                await MainActor.run {
                    self.alarms = updatedAlarms
                    let alertingId = updatedAlarms.first(where: { $0.state == .alerting })?.id
                    self.currentAlertingAlarmId = alertingId
                    // Notify the UI so the mission appears even if the app is already foregrounded
                    // (scenePhase won't change in that case).
                    if alertingId != nil {
                        NotificationCenter.default.post(name: NSNotification.Name("AlarmDidStartAlerting"), object: nil)
                    }
                }
            }
        }
    }

    private func observeAuth() {
        Task {
            for await state in manager.authorizationUpdates {
                await MainActor.run {
                    self.authorizationState = state
                }
            }
        }
    }

    private func indexToWeekday(_ index: Int) -> Locale.Weekday? {
        switch index {
        case 0: return .sunday
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        default: return nil
        }
    }
}
