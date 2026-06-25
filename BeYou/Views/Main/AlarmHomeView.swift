import SwiftUI
import Combine

@available(iOS 16.0, *)
struct AlarmHomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var alarms: [AlarmItem] = []
    @State private var editingAlarm: AlarmItem?
    @State private var showAddAlarm = false
    @State private var showSettings = false
    @State private var showAffirmationDetail = false
    @AppStorage("selectedMotivationTheme") private var affirmationThemeId: String = "starry-mountains"
    @AppStorage("selectedAffirmationCategories") private var selectedCategoriesData: Data = Data()

    // Direct mission / sound editing from the home cards
    @State private var pickerAlarmId: UUID?
    @State private var showMissionPicker = false
    @State private var showSoundPicker = false
    @State private var editMissions: [String] = []
    @State private var editSound: String = "Default"
    private let sounds = [
        "Default", "Annoying", "Beeping", "Zen",
        "Nature", "Rooster", "Kalimba", "Guitar", "Jazz", "Lofi Piano", "Melodic",
        "Loud Bell", "Buzzer", "Loud Impact", "Fighter Jet", "Navy", "Raid"
    ]
    /// Ticks forward so the next-alarm choice + countdown stay live as time passes.
    @State private var now = Date()
    @State private var streakCount: Int = 0
    @Environment(\.scenePhase) private var scenePhase

    private var userName: String {
        appState.onboardingData.name ?? "there"
    }

    /// The closest upcoming alarm from the active alarm list, with its next fire date.
    private var nextAlarm: (alarm: AlarmItem, date: Date)? {
        AlarmScheduler.nextAlarm(from: alarms, now: now)
    }

    // MARK: - Weekly tracker

    private var todayDayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday - 1 // 0 = Sunday
    }

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    @AppStorage("alarmCompletedDays") private var completedDaysData: Data = Data()

    private var completedDays: Set<String> {
        guard let decoded = try? JSONDecoder().decode(Set<String>.self, from: completedDaysData) else {
            return []
        }
        return decoded
    }

    private func isDayCompleted(_ dayIndex: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today) - 1

        // Only show completed for days in the current week that have passed
        if dayIndex > currentWeekday { return false }

        let daysAgo = currentWeekday - dayIndex
        guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return false }
        let dateString = Self.dateFormatter.string(from: date)
        return completedDays.contains(dateString)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F8F8F8").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection

                        // Weekly tracker
                        weeklyTracker
                            .padding(.horizontal, 20)

                        if let next = nextAlarm {
                            // Next Wake Up card
                            nextWakeUpCard(next.alarm, fireDate: next.date)
                                .padding(.horizontal, 20)

                            // Mission & Sound cards
                            HStack(spacing: 12) {
                                missionCard(next.alarm)
                                soundCard(next.alarm)
                            }
                            .padding(.horizontal, 20)
                        } else {
                            emptyStateCard
                                .padding(.horizontal, 20)
                        }

                        // Today's Affirmation
                        todaysAffirmationSection

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $editingAlarm) { alarm in
                AddAlarmSheet(
                    existingAlarm: alarm,
                    onSave: { updated in
                        if let index = alarms.firstIndex(where: { $0.id == updated.id }) {
                            alarms[index] = updated
                        }
                        AlarmScheduler.saveAlarms(alarms)
                        AlarmScheduler.sync(updated)
                        AnalyticsManager.shared.trackAlarmEdited(updated)
                        editingAlarm = nil
                    },
                    onCancel: { editingAlarm = nil }
                )
            }
            .sheet(isPresented: $showAddAlarm) {
                AddAlarmSheet(
                    onSave: { alarm in
                        alarms.append(alarm)
                        AlarmScheduler.saveAlarms(alarms)
                        AlarmScheduler.sync(alarm)
                        AnalyticsManager.shared.trackAlarmCreated(alarm)
                        showAddAlarm = false
                    },
                    onCancel: { showAddAlarm = false }
                )
            }
            .fullScreenCover(isPresented: $showAffirmationDetail) {
                TodayAffirmationDetailView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showMissionPicker, onDismiss: persistMissionEdit) {
                MissionPickerSheet(
                    selectedMissions: $editMissions,
                    isPresented: $showMissionPicker
                )
            }
            .sheet(isPresented: $showSoundPicker, onDismiss: persistSoundEdit) {
                SoundPickerSheet(
                    selectedSound: $editSound,
                    isPresented: $showSoundPicker,
                    sounds: sounds
                )
            }
        }
        .onAppear {
            // Just load what the view displays — the heavy refresh runs once per launch/foreground
            // in MainAppView, not on every tab switch (that was the lag).
            alarms = AlarmScheduler.loadAlarms()
            now = Date()
            streakCount = AlarmCompletionStore.currentStreak()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                alarms = AlarmScheduler.loadAlarms()
                now = Date()
                streakCount = AlarmCompletionStore.currentStreak()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("BeYou Alarm")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
            }

            Spacer()

            // Day streak
            HStack(spacing: 5) {
                Text("🔥")
                    .font(.system(size: 18))
                Text("\(streakCount)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color(hex: "EEEEEE"))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Weekly Tracker

    private var weeklyTracker: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 6) {
                    Text(dayLabels[index])
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(index == todayDayIndex ? Color(hex: "1A1A1A") : Color(hex: "999999"))

                    ZStack {
                        Circle()
                            .fill(
                                index == todayDayIndex
                                    ? Color(hex: "6C5CE7")
                                    : (isDayCompleted(index) ? Color(hex: "6C5CE7").opacity(0.2) : Color(hex: "E8E8E8"))
                            )
                            .frame(width: 36, height: 36)

                        if isDayCompleted(index) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(index == todayDayIndex ? .white : Color(hex: "6C5CE7"))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Next Wake Up Card

    private func nextWakeUpCard(_ alarm: AlarmItem, fireDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Wake Up")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(relativeDayLabel(fireDate))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "999999"))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(alarm.timeOnly)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "1A1A1A"))

                        Text(alarm.periodOnly.lowercased())
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "999999"))

                        Image(systemName: "moon.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6C5CE7"))
                            .padding(.leading, 4)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(ringsInText(fireDate))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "999999"))
                }

                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { Haptics.tap(); editingAlarm = alarm }
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "alarm")
                .font(.system(size: 44))
                .foregroundColor(Color(hex: "C8C2F0"))

            Text("No upcoming alarm")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(Color(hex: "1A1A1A"))

            Text("Set an alarm and you'll have to complete a mission to turn it off.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "999999"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 16)

            Button(action: { showAddAlarm = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("Set an Alarm")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "6C5CE7"))
                .cornerRadius(14)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Mission Card

    private func missionCard(_ alarm: AlarmItem) -> some View {
        Button(action: {
            pickerAlarmId = alarm.id
            editMissions = alarm.missionList
            showMissionPicker = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(alarm.missionList.joined(separator: " + "))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .lineLimit(2)

                Text(alarm.missionList.count > 1 ? "Missions" : "Mission")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "999999"))

                Spacer()

                HStack(spacing: 8) {
                    Spacer()
                    ForEach(alarm.missionList, id: \.self) { m in
                        Image(systemName: AlarmItem.iconName(for: m))
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: AlarmItem.colorHex(for: m)))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(HapticButtonStyle())
    }

    // MARK: - Sound Card

    private func soundCard(_ alarm: AlarmItem) -> some View {
        Button(action: {
            pickerAlarmId = alarm.id
            editSound = alarm.sound
            showSoundPicker = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(alarm.sound)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text("Sound")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "999999"))

                Spacer()

                HStack {
                    Spacer()
                    Image(systemName: "bell.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "6C5CE7"))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(HapticButtonStyle())
    }

    // MARK: - Direct Mission / Sound Editing

    private func persistMissionEdit() {
        guard let id = pickerAlarmId,
              let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        var alarm = alarms[index]
        alarm.mission = editMissions.first ?? "Item Search"
        alarm.secondMission = editMissions.count > 1 ? editMissions[1] : nil
        alarms[index] = alarm
        AlarmScheduler.saveAlarms(alarms)
        AlarmScheduler.sync(alarm)
        AnalyticsManager.shared.trackAlarmEdited(alarm, field: "missions")
        pickerAlarmId = nil
    }

    private func persistSoundEdit() {
        guard let id = pickerAlarmId,
              let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        var alarm = alarms[index]
        alarm.sound = editSound
        alarms[index] = alarm
        AlarmScheduler.saveAlarms(alarms)
        AlarmScheduler.sync(alarm)
        AnalyticsManager.shared.trackAlarmEdited(alarm, field: "sound")
        pickerAlarmId = nil
    }

    // MARK: - Today's Affirmation

    private var affirmationTheme: MotivationTheme {
        defaultThemes.first(where: { $0.id == affirmationThemeId }) ?? defaultThemes[0]
    }

    /// Categories the daily card draws from: the user's picks in the motivation
    /// page, or Self-love + Confidence when nothing is selected.
    private var cardCategories: [String] {
        let raw = (try? JSONDecoder().decode(Set<String>.self, from: selectedCategoriesData)) ?? []
        let cleaned = raw.filter { !$0.hasPrefix("__religion_") && $0 != "Favourites" }
        return cleaned.isEmpty ? ["Self-love", "Confidence"] : Array(cleaned)
    }

    /// One affirmation chosen per calendar day from the selected categories.
    /// Stable for the whole day, changes the next day.
    private var todaysAffirmation: String {
        let data = appState.onboardingData
        let cats = cardCategories
        let catSet = Set(cats)
        let matched = AffirmationService.shared.getAllMatchedAffirmations(
            categories: cats,
            goals: data.goals,
            belief: data.beliefs.first ?? "general",
            name: data.name ?? ""
        )
        // Keep only affirmations actually in the selected categories
        let inCategory = matched.filter { !Set($0.categories).isDisjoint(with: catSet) }
        let pool = (inCategory.isEmpty ? matched : inCategory).map { $0.text }
        guard !pool.isEmpty else { return "You are exactly where you need to be." }
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let daySeed = (comps.year ?? 2026) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
        return pool[daySeed % pool.count]
    }

    private var todaysAffirmationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Affirmation")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))

            affirmationCard
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture {
                    Haptics.tap()
                    AnalyticsManager.shared.trackAffirmationDetailOpened(categories: cardCategories)
                    showAffirmationDetail = true
                }
        }
        .padding(.horizontal, 20)
    }

    private var affirmationCard: some View {
        Text(todaysAffirmation.uppercased())
            .font(.system(size: 22, weight: .heavy))
            .foregroundColor(Color(hex: affirmationTheme.textColor))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .lineLimit(6)
            .minimumScaleFactor(0.6)
            .tracking(0.5)
            .shadow(color: Color.black.opacity(affirmationTheme.type == "solid" ? 0 : 0.5), radius: 4, x: 0, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(20)
            .frame(height: 240)
            .background(affirmationCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// The motivation-tab background (image / gradient / solid) plus a darkening
    /// overlay so the affirmation text stays readable.
    private var affirmationCardBackground: some View {
        ZStack {
            GeometryReader { geo in
                Group {
                    if affirmationTheme.type == "image" {
                        Image(affirmationTheme.background)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if affirmationTheme.type == "gradient", let end = affirmationTheme.gradientEnd {
                        LinearGradient(
                            colors: [Color(hex: affirmationTheme.background), Color(hex: end)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color(hex: affirmationTheme.background)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }

            if affirmationTheme.type != "solid" {
                LinearGradient(
                    colors: [Color.black.opacity(0.1), Color.black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Helpers

    private func relativeDayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private func ringsInText(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: date)
        let days = comps.day ?? 0
        let hours = comps.hour ?? 0
        let minutes = comps.minute ?? 0

        if days > 0 { return "Rings in \(days)d \(hours)h" }
        if hours > 0 { return "Rings in \(hours)h \(minutes)m" }
        return "Rings in \(minutes)m"
    }
}
