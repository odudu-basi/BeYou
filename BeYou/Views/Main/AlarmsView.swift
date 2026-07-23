import SwiftUI
import UIKit

// MARK: - Alarm Model

struct AlarmItem: Codable, Identifiable {
    var id = UUID()
    var name: String
    var hour: Int
    var minute: Int
    var isEnabled: Bool = true
    var isScheduled: Bool = true // true = recurring, false = one-time
    var repeatDays: Set<Int> = Set(0...4) // 0=Mon, 1=Tue...6=Sun
    var mission: String = "Item Search"
    var secondMission: String? = nil   // optional 2nd mission to complete in sequence
    var selectedObjects: [String]? = nil   // items for the Item Search mission
    var exerciseSeconds: Int? = nil        // duration for exercise missions (Push Ups / Squats)
    var sound: String = "Default"
    var wakeUpCheckEnabled: Bool = false

    /// All missions for this alarm, in order (1 or 2).
    var missionList: [String] {
        secondMission.map { [mission, $0] } ?? [mission]
    }

    var formattedTime: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let m = String(format: "%02d", minute)
        let period = hour < 12 ? "AM" : "PM"
        return "\(h):\(m) \(period)"
    }

    var periodOnly: String {
        hour < 12 ? "AM" : "PM"
    }

    var timeOnly: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let m = String(format: "%02d", minute)
        return "\(h):\(m)"
    }

    var daysLabel: String {
        if !isScheduled { return "One-time" }
        if repeatDays.count == 7 { return "Every day" }
        if repeatDays == Set(0...4) { return "Weekdays" }
        if repeatDays == Set([5, 6]) { return "Weekends" }
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return repeatDays.sorted().map { dayNames[$0] }.joined(separator: ", ")
    }

    var missionIcon: String { AlarmItem.iconName(for: mission) }
    var missionColorHex: String { AlarmItem.colorHex(for: mission) }

    /// All available wake-up missions (display order).
    static let allMissions = ["Item Search", "Picture of Sky", "Make Your Bed", "Solve Math", "Touch Grass", "Push Ups", "Squats"]

    /// Camera-based exercise missions: record a short video, verified by AI.
    static let exerciseMissions: Set<String> = ["Push Ups", "Squats"]
    static func isExercise(_ mission: String) -> Bool { exerciseMissions.contains(mission) }

    static func iconName(for mission: String) -> String {
        switch mission {
        case "Item Search": return "camera.viewfinder"
        case "Picture of Sky": return "sun.max.fill"
        case "Make Your Bed": return "bed.double.fill"
        case "Solve Math": return "function"
        case "Touch Grass": return "leaf.fill"
        case "Push Ups": return "figure.core.training"
        case "Squats": return "figure.cross.training"
        default: return "camera.viewfinder"
        }
    }

    static func colorHex(for mission: String) -> String {
        switch mission {
        case "Item Search": return "3B82F6"     // blue
        case "Picture of Sky": return "F5A623"   // amber
        case "Make Your Bed": return "6C5CE7"    // purple
        case "Solve Math": return "EF4444"       // red
        case "Touch Grass": return "27AE60"      // green
        case "Push Ups": return "FF7043"         // deep orange
        case "Squats": return "8D6E63"           // brown
        default: return "3B82F6"
        }
    }

    // MARK: - Item Search objects

    /// All findable objects, in display order, with their emoji.
    static let objectCatalog: [(name: String, emoji: String)] = [
        ("Toothbrush", "🪥"), ("Running Faucet", "🚰"), ("Shoes", "👟"),
        ("Fridge", "🧊"), ("Keys", "🔑"), ("Coffee Mug", "☕"),
        ("Mirror", "🪞"), ("Water Bottle", "💧"), ("Dustpan", "🧹"),
        ("Toilet", "🚽"), ("Book", "📕"), ("Lamp", "💡"),
        ("TV Remote", "📺"), ("Front Door", "🚪"), ("Stove", "🍳"),
        ("Lotion Bottle", "🧴"), ("Soap", "🧼"), ("Plant", "🪴"),
        ("Plate", "🍽️"), ("Towel", "🧖"), ("Backpack", "🎒"),
        ("Headphones", "🎧"), ("Shower", "🚿"), ("Tape", "📦"),
        ("Kim Kardashian", "👩"), ("Snoop Dogg", "🐶"), ("Rubber Duck", "🦆"),
    ]

    /// Default selection (the standard household set) for a new Item Search alarm.
    static let defaultObjects: [String] = [
        "Toothbrush", "Running Faucet", "Shoes", "Fridge", "Keys", "Coffee Mug",
        "Mirror", "Water Bottle", "Toilet", "Book", "Lamp", "TV Remote",
        "Front Door", "Stove", "Lotion Bottle", "Soap", "Plant", "Plate",
        "Towel", "Backpack", "Headphones", "Shower", "Tape"
    ]

    static func objectEmoji(_ name: String) -> String {
        objectCatalog.first { $0.name == name }?.emoji ?? "❓"
    }
}

// MARK: - Alarms View

@available(iOS 16.0, *)
struct AlarmsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var alarms: [AlarmItem] = []
    @State private var showAddAlarm = false
    @State private var editingAlarm: AlarmItem?

    /// Alarms ordered for display: enabled ones first (disabled sink to the bottom), each group
    /// sorted by clock time. Computed at render, so toggling an alarm on/off re-sorts it into
    /// place automatically.
    private var sortedAlarms: [AlarmItem] {
        alarms.sorted { a, b in
            if a.isEnabled != b.isEnabled { return a.isEnabled }   // enabled before disabled
            if a.hour != b.hour { return a.hour < b.hour }         // earliest hour first
            return a.minute < b.minute                             // then earliest minute
        }
    }

    // App Block
    @AppStorage("appBlockEnabled") private var appBlockEnabled: Bool = false
    @AppStorage("appBlockActive") private var appBlockActive: Bool = false
    @State private var showAppBlockSheet = false
    @State private var showUnblockIntervention = false

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    Text("Alarms")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // App Block container
                    appBlockBanner
                        .padding(.horizontal, 20)

                    if alarms.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)

                            Image(systemName: "alarm.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "CCCCCC"))

                            Text("No alarms yet")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text("Tap + to set your first alarm")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))

                            Spacer()
                        }
                    } else {
                        // Alarm cards
                        ForEach(sortedAlarms) { alarm in
                            AlarmCard(
                                alarm: alarm,
                                onEdit: { editingAlarm = alarm },
                                onDelete: { deleteAlarm(alarm) },
                                onToggle: { newValue in toggleAlarm(alarm, to: newValue) }
                            )
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer().frame(height: 120)
                }
            }

            // Floating add button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showAddAlarm = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(hex: "1A1A1A"))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            // Just load the list to display — heavy refresh runs once per launch/foreground in
            // MainAppView, not on every tab switch.
            loadAlarms()
        }
        .sheet(isPresented: $showAddAlarm) {
            AddAlarmSheet(
                onSave: { alarm in
                    alarms.append(alarm)
                    saveAlarms()
                    await AlarmScheduler.syncAwaiting(alarm)   // wait until fully armed on the OS
                    AnalyticsManager.shared.trackAlarmCreated(alarm)
                    showAddAlarm = false
                },
                onCancel: { showAddAlarm = false }
            )
        }
        .sheet(item: $editingAlarm) { alarm in
            AddAlarmSheet(
                existingAlarm: alarm,
                onSave: { edited in
                    // Editing + saving an alarm is an explicit intent to use it at the new time.
                    // Re-enable it so a one-time alarm that was auto-disabled after completing its
                    // mission (disableIfOneTime) actually re-arms — otherwise sync() sees
                    // isEnabled=false and cancels instead of scheduling, so the edit never rings.
                    var updated = edited
                    updated.isEnabled = true
                    let idTag = String(updated.id.uuidString.suffix(4))
                    print("⏰ EDIT[\(idTag)]: user saved edit '\(alarm.name)' \(String(format: "%02d:%02d", alarm.hour, alarm.minute)) → '\(updated.name)' \(String(format: "%02d:%02d", updated.hour, updated.minute)) enabled=\(updated.isEnabled) wasEnabled=\(edited.isEnabled)")
                    if let index = alarms.firstIndex(where: { $0.id == updated.id }) {
                        alarms[index] = updated
                        saveAlarms()
                    }
                    await AlarmScheduler.syncAwaiting(updated)   // wait until fully armed on the OS
                    AnalyticsManager.shared.trackAlarmEdited(updated)
                    editingAlarm = nil
                },
                onCancel: { editingAlarm = nil }
            )
        }
        .sheet(isPresented: $showAppBlockSheet) {
            AppBlockSheet()
                .environmentObject(screenTimeManager)
        }
        .fullScreenCover(isPresented: $showUnblockIntervention) {
            AppBlockInterventionSheet()
                .environmentObject(appState)
                .environmentObject(screenTimeManager)
        }
    }

    // MARK: - App Block Banner

    private var appBlockBanner: some View {
        // active (blocking now) = red, enabled (armed) = green, off = gray
        let stateColor = appBlockActive ? Color(hex: "EF4444")
            : (appBlockEnabled ? Color(hex: "34C759") : Color(hex: "999999"))
        let subtitle = appBlockActive ? "Apps blocked"
            : (appBlockEnabled ? "Apps blocked" : "Off")

        return VStack(spacing: 0) {
            Button(action: { showAppBlockSheet = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(stateColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 18))
                            .foregroundColor(stateColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Block")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(stateColor)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "CCCCCC"))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())

            if appBlockActive {
                Divider().padding(.leading, 16)

                Button(action: { showUnblockIntervention = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 18))
                        Text("Stop")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "EF4444"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func loadAlarms() {
        alarms = AlarmScheduler.loadAlarms()
    }

    private func saveAlarms() {
        AlarmScheduler.saveAlarms(alarms)
    }

    private func deleteAlarm(_ alarm: AlarmItem) {
        AlarmScheduler.cancel(alarm)
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
        AlarmScheduler.refresh()
        AnalyticsManager.shared.trackAlarmDeleted(alarm, source: "alarms_tab")
    }

    private func toggleAlarm(_ alarm: AlarmItem, to enabled: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index].isEnabled = enabled
        saveAlarms()
        AlarmScheduler.sync(alarms[index])
        AnalyticsManager.shared.trackAlarmToggled(alarms[index], enabled: enabled)
    }
}

// MARK: - Alarm Card

struct AlarmCard: View {
    let alarm: AlarmItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: (Bool) -> Void

    @State private var offset: CGFloat = 0
    private let deleteWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete action revealed on left swipe
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                onDelete()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                    Text("Delete")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: deleteWidth)
                .frame(maxHeight: .infinity)
                .background(Color(hex: "EF4444"))
                .cornerRadius(16)
            }
            .opacity(offset < 0 ? 1 : 0)

            cardContent
                .offset(x: offset)
                .onTapGesture {
                    Haptics.tap()
                    if offset != 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                    } else {
                        onEdit()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -deleteWidth)
                            } else if offset < 0 {
                                offset = min(0, -deleteWidth + value.translation.width)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = value.translation.width < -deleteWidth / 2 ? -deleteWidth : 0
                            }
                        }
                )
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
                // Days label
                Text(alarm.daysLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "999999"))

                // Time row
                HStack(alignment: .firstTextBaseline) {
                    Text(alarm.timeOnly)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(alarm.isEnabled ? Color(hex: "1A1A1A") : Color(hex: "BBBBBB"))

                    Text(alarm.periodOnly)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(alarm.isEnabled ? Color(hex: "1A1A1A") : Color(hex: "BBBBBB"))

                    Spacer()

                    Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: { onToggle($0) }))
                        .labelsHidden()
                        .tint(Color(hex: "34C759"))
                }

                // Mission label
                HStack(spacing: 6) {
                    Text(alarm.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(alarm.isEnabled ? Color(hex: "666666") : Color(hex: "BBBBBB"))

                    Text("·")
                        .foregroundColor(Color(hex: "CCCCCC"))

                    ForEach(alarm.missionList, id: \.self) { m in
                        MissionIcon(mission: m, systemName: AlarmItem.iconName(for: m), size: 12)
                            .foregroundColor(alarm.isEnabled ? Color(hex: AlarmItem.colorHex(for: m)) : Color(hex: "BBBBBB"))
                    }

                    Text(alarm.missionList.joined(separator: " + "))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(alarm.isEnabled ? Color(hex: "666666") : Color(hex: "BBBBBB"))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            .contentShape(Rectangle())
            .contextMenu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Alarm", systemImage: "trash")
                }
            }
    }
}

// MARK: - Add Alarm Sheet

struct AddAlarmSheet: View {
    var existingAlarm: AlarmItem?
    let onSave: (AlarmItem) async -> Void
    let onCancel: () -> Void

    @State private var isSaving = false   // Save shows a spinner + is disabled until fully armed

    @State private var name: String = ""
    @State private var selectedTime = Date()
    @State private var isScheduled: Bool = true
    @State private var repeatDays: Set<Int> = Set(0...4)
    @State private var selectedMissions: [String] = ["Item Search"]   // up to 2, in order
    @State private var selectedObjects: Set<String> = Set(AlarmItem.defaultObjects)
    @State private var exerciseSeconds: Int = 15   // Push Ups / Squats recording duration
    @State private var selectedSound: String = "Default"
    @State private var wakeUpCheckEnabled: Bool = false
    @State private var showMissionPicker = false
    @State private var showObjectPicker = false
    @State private var showSoundPicker = false
    @State private var showWakeUpCheckInfo = false

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private let sounds = [
        "Default", "Annoying", "Beeping", "Zen",
        "Nature", "Rooster", "Kalimba", "Guitar", "Jazz", "Lofi Piano", "Melodic",
        "Loud Bell", "Buzzer", "Loud Impact", "Fighter Jet", "Navy", "Raid"
    ]

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: selectedTime)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Alarm name", text: $name)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color(hex: "F0F0F0"))
                            .cornerRadius(14)
                    }

                    // Alarm time
                    HStack {
                        Text("Alarm Time")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A1A"))

                        Spacer()

                        DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .padding(16)
                    .background(Color(hex: "F0F0F0"))
                    .cornerRadius(14)

                    // Scheduled / One-time toggle
                    HStack(spacing: 0) {
                        Button(action: { isScheduled = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 14))
                                Text("Scheduled")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isScheduled ? Color.white : Color.clear)
                            .cornerRadius(10)
                        }
                        .foregroundColor(isScheduled ? Color(hex: "1A1A1A") : Color(hex: "999999"))

                        Button(action: { isScheduled = false }) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                Text("One-time")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(!isScheduled ? Color.white : Color.clear)
                            .cornerRadius(10)
                        }
                        .foregroundColor(!isScheduled ? Color(hex: "1A1A1A") : Color(hex: "999999"))
                    }
                    .padding(4)
                    .background(Color(hex: "F0F0F0"))
                    .cornerRadius(14)

                    // Repeat days (only if scheduled)
                    if isScheduled {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Repeat on:")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "666666"))

                            HStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { index in
                                    Button(action: {
                                        if repeatDays.contains(index) {
                                            repeatDays.remove(index)
                                        } else {
                                            repeatDays.insert(index)
                                        }
                                    }) {
                                        Text(dayLabels[index])
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(repeatDays.contains(index) ? .white : Color(hex: "1A1A1A"))
                                            .frame(width: 40, height: 40)
                                            .background(repeatDays.contains(index) ? Color(hex: "1A1A1A") : Color(hex: "F0F0F0"))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(14)
                    }

                    // Mission picker (up to 2)
                    Button(action: { showMissionPicker = true }) {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                ForEach(selectedMissions, id: \.self) { m in
                                    MissionIcon(mission: m, systemName: AlarmItem.iconName(for: m), size: 18)
                                        .foregroundColor(Color(hex: AlarmItem.colorHex(for: m)))
                                }
                            }
                            .frame(minWidth: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedMissions.count > 1 ? "Missions (2)" : "Mission")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Text(selectedMissions.joined(separator: " + "))
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "999999"))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "CCCCCC"))
                        }
                        .padding(16)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(14)
                    }
                    .buttonStyle(HapticButtonStyle())

                    // Exercise duration (Push Ups / Squats) — how long to record.
                    if selectedMissions.contains(where: AlarmItem.isExercise) {
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "FF7043"))
                                .frame(minWidth: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Exercise Duration")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                                Text("Record yourself for this long")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "999999"))
                            }

                            Spacer()

                            HStack(spacing: 14) {
                                Button(action: { exerciseSeconds = max(5, exerciseSeconds - 5) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(Color(hex: exerciseSeconds > 5 ? "1A1A1A" : "CCCCCC"))
                                }
                                Text("\(exerciseSeconds)s")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                                    .frame(minWidth: 42)
                                Button(action: { exerciseSeconds = min(60, exerciseSeconds + 5) }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(Color(hex: exerciseSeconds < 60 ? "1A1A1A" : "CCCCCC"))
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(14)
                    }

                    // Selected objects (only for Item Search)
                    if selectedMissions.contains("Item Search") {
                        Button(action: { showObjectPicker = true }) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Selected Objects · \(selectedObjects.count)")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "1A1A1A"))

                                    Spacer()

                                    HStack(spacing: 4) {
                                        Text("Change")
                                            .font(.system(size: 14, weight: .semibold))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(Color(hex: "3B82F6"))
                                }

                                HStack(spacing: 8) {
                                    let preview = AlarmItem.objectCatalog.map(\.name).filter { selectedObjects.contains($0) }
                                    ForEach(preview.prefix(5), id: \.self) { name in
                                        Text(AlarmItem.objectEmoji(name))
                                            .font(.system(size: 26))
                                            .frame(width: 48, height: 48)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color(hex: "E2E2E2"), lineWidth: 1)
                                            )
                                    }
                                    if selectedObjects.count > 5 {
                                        Text("+\(selectedObjects.count - 5)")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(hex: "666666"))
                                            .frame(width: 48, height: 48)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color(hex: "E2E2E2"), lineWidth: 1)
                                            )
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                            .padding(16)
                            .background(Color(hex: "F0F0F0"))
                            .cornerRadius(14)
                        }
                        .buttonStyle(HapticButtonStyle())
                    }

                    // Sound picker
                    Button(action: { showSoundPicker = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "999999"))
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sound")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Text(selectedSound)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "999999"))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "CCCCCC"))
                        }
                        .padding(16)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(14)
                    }
                    .buttonStyle(HapticButtonStyle())

                    // Wake-up Check
                    Button(action: { showWakeUpCheckInfo = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "alarm.waves.left.and.right")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "6C5CE7"))
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "6C5CE7").opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Wake-up Check")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "1A1A1A"))

                                    Text(wakeUpCheckEnabled ? "On" : "Off")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(wakeUpCheckEnabled ? Color(hex: "34C759") : Color(hex: "999999"))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(wakeUpCheckEnabled ? Color(hex: "34C759").opacity(0.12) : Color(hex: "EEEEEE"))
                                        .cornerRadius(4)
                                }

                                Text("A second alarm so you don't fall back asleep")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "999999"))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "CCCCCC"))
                        }
                        .padding(16)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(14)
                    }
                    .buttonStyle(HapticButtonStyle())

                    Spacer().frame(height: 20)

                    // Save button — shows a spinner and blocks until the alarm is fully armed on
                    // iOS, so killing the app right after Save can't leave it half-scheduled.
                    Button(action: saveAlarm) {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(existingAlarm != nil ? "Save Changes" : "Save Alarm")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background((name.isEmpty || isSaving) ? Color(hex: "CCCCCC") : Color(hex: "1A1A1A"))
                        .cornerRadius(16)
                    }
                    .disabled(name.isEmpty || isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(hex: "F8F8F8"))
            .navigationTitle(existingAlarm != nil ? "Edit Alarm" : "New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "CCCCCC"))
                    }
                }
            }
            .sheet(isPresented: $showMissionPicker) {
                MissionPickerSheet(
                    selectedMissions: $selectedMissions,
                    isPresented: $showMissionPicker
                )
            }
            .sheet(isPresented: $showObjectPicker) {
                ItemSearchPickerSheet(
                    selectedItems: $selectedObjects,
                    isPresented: $showObjectPicker
                )
            }
            .sheet(isPresented: $showSoundPicker) {
                SoundPickerSheet(
                    selectedSound: $selectedSound,
                    isPresented: $showSoundPicker,
                    sounds: sounds
                )
            }
            .sheet(isPresented: $showWakeUpCheckInfo) {
                WakeUpCheckSheet(
                    isEnabled: $wakeUpCheckEnabled,
                    isPresented: $showWakeUpCheckInfo
                )
            }
        }
        .onAppear {
            if let existing = existingAlarm {
                name = existing.name
                isScheduled = existing.isScheduled
                repeatDays = existing.repeatDays
                selectedMissions = existing.missionList
                selectedObjects = Set(existing.selectedObjects ?? AlarmItem.defaultObjects)
                exerciseSeconds = existing.exerciseSeconds ?? 15
                selectedSound = existing.sound
                wakeUpCheckEnabled = existing.wakeUpCheckEnabled
                let calendar = Calendar.current
                selectedTime = calendar.date(bySettingHour: existing.hour, minute: existing.minute, second: 0, of: Date()) ?? Date()
            } else {
                let count = (UserDefaults.standard.data(forKey: "savedAlarms")
                    .flatMap { try? JSONDecoder().decode([AlarmItem].self, from: $0) }?.count ?? 0) + 1
                name = "Alarm #\(count)"
            }
        }
    }

    private func saveAlarm() {
        let calendar = Calendar.current
        var alarm = existingAlarm ?? AlarmItem(
            name: name,
            hour: calendar.component(.hour, from: selectedTime),
            minute: calendar.component(.minute, from: selectedTime)
        )
        alarm.name = name
        alarm.hour = calendar.component(.hour, from: selectedTime)
        alarm.minute = calendar.component(.minute, from: selectedTime)
        alarm.isScheduled = isScheduled
        alarm.repeatDays = repeatDays
        alarm.mission = selectedMissions.first ?? "Item Search"
        alarm.secondMission = selectedMissions.count > 1 ? selectedMissions[1] : nil
        alarm.selectedObjects = selectedMissions.contains("Item Search") ? Array(selectedObjects) : nil
        alarm.exerciseSeconds = selectedMissions.contains(where: AlarmItem.isExercise) ? exerciseSeconds : nil
        alarm.sound = selectedSound
        alarm.wakeUpCheckEnabled = wakeUpCheckEnabled

        // Show the spinner and hold the sheet open until the alarm is fully armed on iOS. A
        // failure-only 30s safety net guarantees the spinner can never run forever (on a hang we
        // just proceed; reconcile heals the rest on next open).
        isSaving = true
        Task {
            // Background-time assertion: if the user backgrounds the app mid-save, iOS would
            // otherwise suspend us within seconds and freeze scheduling half-done (the "doesn't
            // ring until I open the app" bug). This asks iOS for extra time to finish the burst.
            let bgTask = UIApplication.shared.beginBackgroundTask(withName: "AlarmScheduling")
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await onSave(alarm) }
                group.addTask { try? await Task.sleep(nanoseconds: 30_000_000_000) }
                await group.next()
                group.cancelAll()
            }
            isSaving = false
            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask) }
        }
    }
}

// MARK: - Wake-up Check Sheet

struct WakeUpCheckSheet: View {
    @Binding var isEnabled: Bool
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "DDDDDD"))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Wake-up Check")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Text("A second alarm 10 minutes after the first — so you can't just go back to sleep.")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "666666"))
                        .lineSpacing(4)

                    // Info cards
                    VStack(spacing: 12) {
                        wakeUpCheckInfoRow(
                            icon: "alarm.waves.left.and.right",
                            iconColor: Color(hex: "6C5CE7"),
                            title: "Fires 10 minutes later",
                            description: "After you finish your first alarm's mission, a second alarm goes off 10 minutes later to make sure you really got up."
                        )

                        wakeUpCheckInfoRow(
                            icon: "keyboard.fill",
                            iconColor: Color(hex: "3B82F6"),
                            title: "Type a phrase to dismiss",
                            description: "You have to type a random word or phrase to prove you're awake. A new word every time."
                        )
                    }

                    Spacer().frame(height: 20)

                    // Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Wake-up Check")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text(isEnabled ? "On" : "Off")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "999999"))
                        }

                        Spacer()

                        Toggle("", isOn: $isEnabled)
                            .labelsHidden()
                            .tint(Color(hex: "34C759"))
                    }
                    .padding(16)
                    .background(Color(hex: "F0F0F0"))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }

            // Done button
            Button(action: { isPresented = false }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "1A1A1A"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Color(hex: "F8F8F8"))
    }

    private func wakeUpCheckInfoRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "888888"))
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - Mission Picker Sheet

struct MissionPickerSheet: View {
    @Binding var selectedMissions: [String]
    @Binding var isPresented: Bool

    private func toggle(_ mission: String) {
        if let idx = selectedMissions.firstIndex(of: mission) {
            // Don't allow removing the last one — an alarm needs at least one mission.
            if selectedMissions.count > 1 { selectedMissions.remove(at: idx) }
        } else if selectedMissions.count < 2 {
            selectedMissions.append(mission)
        } else {
            // Already 2 picked: replace the second.
            selectedMissions[1] = mission
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text("Pick 1 mission — or add a 2nd to do back-to-back.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "999999"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(AlarmItem.allMissions, id: \.self) { mission in
                    let isSelected = selectedMissions.contains(mission)
                    let order = (selectedMissions.firstIndex(of: mission)).map { $0 + 1 }
                    Button(action: { toggle(mission) }) {
                        HStack(spacing: 14) {
                            MissionIcon(mission: mission, systemName: AlarmItem.iconName(for: mission), size: 18, twoTone: true)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color(hex: AlarmItem.colorHex(for: mission)))
                                .clipShape(Circle())

                            Text(mission)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Spacer()

                            if let order, selectedMissions.count > 1 {
                                Text("\(order)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Color(hex: "34C759"))
                                    .clipShape(Circle())
                            } else if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(hex: "34C759"))
                            }
                        }
                        .padding(14)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color(hex: "34C759") : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(HapticButtonStyle())
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .background(Color(hex: "F8F8F8"))
            .navigationTitle("Choose Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Done").fixedSize()   // don't let the inline title squeeze it
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Sound Picker Sheet

struct SoundPickerSheet: View {
    @Binding var selectedSound: String
    @Binding var isPresented: Bool
    let sounds: [String]
    @ObservedObject private var preview = SoundPreviewPlayer.shared

    private func iconFor(_ sound: String) -> String {
        switch sound {
        case "Default": return "speaker.wave.2.fill"
        case "Annoying": return "exclamationmark.triangle.fill"
        case "Beeping": return "alarm.fill"
        case "Zen": return "leaf.fill"
        case "Nature": return "tree.fill"
        case "Rooster": return "bird.fill"
        case "Kalimba": return "music.note"
        case "Guitar": return "guitars.fill"
        case "Jazz": return "music.quarternote.3"
        case "Lofi Piano": return "pianokeys"
        case "Melodic": return "music.note.list"
        case "Loud Bell": return "bell.fill"
        case "Buzzer": return "speaker.wave.3.fill"
        case "Loud Impact": return "bolt.fill"
        case "Fighter Jet": return "airplane"
        case "Navy": return "megaphone.fill"
        case "Raid": return "dot.radiowaves.left.and.right"
        default: return "speaker.wave.2.fill"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(sounds, id: \.self) { sound in
                        Button(action: {
                            selectedSound = sound
                            isPresented = false
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: iconFor(sound))
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "666666"))
                                    .frame(width: 36, height: 36)
                                    .background(Color(hex: "EEEEEE"))
                                    .clipShape(Circle())

                                Text(sound)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Spacer()

                                // Preview play / stop (only for sounds with a bundled file)
                                if SoundPreviewPlayer.canPreview(sound) {
                                    Button(action: { preview.toggle(sound) }) {
                                        Image(systemName: preview.playingSound == sound ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(preview.playingSound == sound ? Color(hex: "6C5CE7") : Color(hex: "BBBBBB"))
                                    }
                                    .buttonStyle(HapticButtonStyle())
                                }

                                if selectedSound == sound {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Color(hex: "34C759"))
                                }
                            }
                            .padding(14)
                            .background(Color(hex: "F0F0F0"))
                            .cornerRadius(14)
                        }
                        .buttonStyle(HapticButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(hex: "F8F8F8"))
            .navigationTitle("Choose Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Done").fixedSize()   // don't let the inline title squeeze it
                    }
                }
            }
            .onDisappear { preview.stop() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
