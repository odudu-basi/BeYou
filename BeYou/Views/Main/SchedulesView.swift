import SwiftUI
import FamilyControls

// MARK: - Schedule Session Model

struct ScheduleSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var emoji: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var isEnabled: Bool
    var category: ScheduleCategory
    var daysActive: Set<Int> // 1=Sun, 2=Mon, ... 7=Sat. Empty = every day
    var blockedAppTokensData: Data? // Encoded FamilyActivitySelection for this schedule

    init(id: UUID = UUID(), name: String, emoji: String, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, isEnabled: Bool = false, category: ScheduleCategory = .schedule, daysActive: Set<Int> = [], blockedAppTokensData: Data? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = isEnabled
        self.category = category
        self.daysActive = daysActive
        self.blockedAppTokensData = blockedAppTokensData
    }

    var formattedTime: String {
        let start = formatTime(hour: startHour, minute: startMinute)
        let end = formatTime(hour: endHour, minute: endMinute)
        return "\(start) - \(end)"
    }

    var daysLabel: String {
        if daysActive.isEmpty { return "Every day" }
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sorted = daysActive.sorted()
        if sorted == [2, 3, 4, 5, 6] { return "Weekdays" }
        if sorted == [1, 7] { return "Weekends" }
        return sorted.map { dayNames[$0] }.joined(separator: ", ")
    }

    var blockedAppsCount: Int {
        guard let data = blockedAppTokensData,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return 0
        }
        return selection.applicationTokens.count
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if minute == 0 {
            return "\(displayHour):00 \(period)"
        }
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }
}

enum ScheduleCategory: String, Codable {
    case blockingNow
    case schedule
    case allDay
}

// MARK: - Preset Ideas

struct ScheduleIdea: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let description: String

    var formattedTime: String {
        let start = formatTime(hour: startHour, minute: startMinute)
        let end = formatTime(hour: endHour, minute: endMinute)
        return "\(start) - \(end)"
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if minute == 0 {
            return "\(displayHour):00 \(period)"
        }
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }

    func toSession() -> ScheduleSession {
        ScheduleSession(
            name: name,
            emoji: emoji,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            isEnabled: true,
            category: .schedule
        )
    }
}

// MARK: - SchedulesView

@available(iOS 16.0, *)
struct SchedulesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var sessions: [ScheduleSession] = []
    @State private var showNewSession = false
    @State private var editingSession: ScheduleSession? = nil
    @State private var wasEditingSessionEnabled = false
    @State private var showOverlapAlert = false
    @State private var overlapAlertMessage = ""

    private let presetIdeas: [ScheduleIdea] = [
        ScheduleIdea(name: "Morning Mindful", emoji: "🌅", startHour: 6, startMinute: 0, endHour: 8, endMinute: 30, description: "Start your day without distractions"),
        ScheduleIdea(name: "Night Mode", emoji: "🌙", startHour: 22, startMinute: 0, endHour: 7, endMinute: 0, description: "Wind down and sleep better"),
        ScheduleIdea(name: "Deep Focus", emoji: "🧠", startHour: 9, startMinute: 30, endHour: 17, endMinute: 0, description: "Lock in during work hours"),
        ScheduleIdea(name: "Dinner Time", emoji: "🍽", startHour: 18, startMinute: 30, endHour: 19, endMinute: 30, description: "Be present with loved ones"),
        ScheduleIdea(name: "Weekend Reset", emoji: "🏖", startHour: 10, startMinute: 0, endHour: 16, endMinute: 0, description: "Enjoy your weekends offline"),
        ScheduleIdea(name: "Study Session", emoji: "📚", startHour: 14, startMinute: 0, endHour: 17, endMinute: 0, description: "Distraction-free studying"),
    ]

    private var activeSessions: [ScheduleSession] {
        sessions.filter { $0.isEnabled }
    }

    private var inactiveSessions: [ScheduleSession] {
        sessions.filter { !$0.isEnabled }
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    Text("Schedules")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .tracking(-0.3)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                    // New Session Button
                    newSessionButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    // Active Sessions
                    if !activeSessions.isEmpty {
                        sectionHeader(title: "Active", count: activeSessions.count, dotColor: Color(hex: "34C759"))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        ForEach(Array(activeSessions.enumerated()), id: \.element.id) { index, session in
                            sessionCard(session: session)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                        }
                        .padding(.bottom, 8)
                    }

                    // Inactive Sessions
                    if !inactiveSessions.isEmpty {
                        sectionHeader(title: "Paused", count: inactiveSessions.count, dotColor: Color(hex: "999999"))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        ForEach(Array(inactiveSessions.enumerated()), id: \.element.id) { index, session in
                            SwipeToDeleteWrapper(onDelete: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    deleteSession(session)
                                }
                            }) {
                                sessionCard(session: session)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                        }
                        .padding(.bottom, 8)
                    }

                    // Ideas Section
                    if !presetIdeas.isEmpty {
                        ideasSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }

                    // Bottom spacer for tab bar
                    Spacer()
                        .frame(height: 120)
                }
            }
        }
        .sheet(isPresented: $showNewSession) {
            NewScheduleSessionSheet(
                sessions: $sessions,
                screenTimeManager: screenTimeManager,
                onOverlapDetected: { message in
                    overlapAlertMessage = message
                    showOverlapAlert = true
                }
            )
        }
        .sheet(item: $editingSession) { session in
            EditScheduleSessionSheet(
                sessions: $sessions,
                session: session,
                wasEnabled: wasEditingSessionEnabled,
                screenTimeManager: screenTimeManager,
                onOverlapDetected: { message in
                    overlapAlertMessage = message
                    showOverlapAlert = true
                }
            )
        }
        .alert("Schedule Overlap", isPresented: $showOverlapAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(overlapAlertMessage)
        }
        .onAppear {
            loadSessions()
        }
    }

    // MARK: - New Session Button

    private var newSessionButton: some View {
        Button(action: { showNewSession = true }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))

                Text("New Scheduled Session")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "1A1A1A"))
            .cornerRadius(14)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int, dotColor: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text("(\(count))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "999999"))
            }

            Spacer()
        }
    }

    // MARK: - Session Card

    private func sessionCard(session: ScheduleSession) -> some View {
        Button(action: {
            // Auto-disable active schedule before editing
            if session.isEnabled {
                wasEditingSessionEnabled = true
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    removeSchedule(sessions[idx])
                    sessions[idx].isEnabled = false
                    saveSessions()
                }
            } else {
                wasEditingSessionEnabled = false
            }
            editingSession = session
        }) {
            HStack(spacing: 14) {
                // Emoji Icon
                ZStack {
                    Circle()
                        .fill(session.isEnabled ? Color(hex: "F0F0F0") : Color(hex: "F8F8F8"))
                        .frame(width: 44, height: 44)

                    Text(session.emoji)
                        .font(.system(size: 22))
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "999999"))

                        Text("\(session.daysLabel) \(session.formattedTime)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "999999"))
                    }

                    // Show blocked apps count
                    if session.blockedAppsCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "999999"))

                            Text("\(session.blockedAppsCount) app\(session.blockedAppsCount == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "999999"))
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Toggle
                Toggle("", isOn: binding(for: session))
                    .labelsHidden()
                    .tint(Color(hex: "1A1A1A"))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(session.isEnabled ? Color(hex: "1A1A1A").opacity(0.1) : Color.clear, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteSession(session)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Ideas Section

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ideas")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .padding(.top, 4)

            ForEach(presetIdeas) { idea in
                ideaCard(idea: idea)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func ideaCard(idea: ScheduleIdea) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "F5F5F5"))
                    .frame(width: 44, height: 44)

                Text(idea.emoji)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(idea.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text(idea.formattedTime)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "999999"))
            }

            Spacer()

            Button(action: { addFromIdea(idea) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "1A1A1A"))
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Overlap Detection

    /// Check if two time ranges overlap, considering days
    private func schedulesOverlap(_ session1: ScheduleSession, _ session2: ScheduleSession) -> Bool {
        // If both have specific days set, check if any days overlap
        if !session1.daysActive.isEmpty && !session2.daysActive.isEmpty {
            let daysOverlap = !session1.daysActive.isDisjoint(with: session2.daysActive)
            if !daysOverlap {
                return false // Different days, no overlap
            }
        }

        // Check if time ranges overlap
        return timeRangesOverlap(
            start1: session1.startHour * 60 + session1.startMinute,
            end1: session1.endHour * 60 + session1.endMinute,
            start2: session2.startHour * 60 + session2.startMinute,
            end2: session2.endHour * 60 + session2.endMinute
        )
    }

    /// Check if two time ranges overlap (times in minutes from midnight)
    private func timeRangesOverlap(start1: Int, end1: Int, start2: Int, end2: Int) -> Bool {
        // Handle overnight schedules (end < start means crosses midnight)
        let overnight1 = end1 < start1
        let overnight2 = end2 < start2

        if overnight1 && overnight2 {
            // Both cross midnight - they always overlap
            return true
        } else if overnight1 {
            // Schedule 1 crosses midnight
            // It occupies: [start1, 1440) and [0, end1)
            // Check if schedule 2 overlaps either segment
            return start2 >= start1 || end2 <= end1 || (start2 < end2 && end2 > start1)
        } else if overnight2 {
            // Schedule 2 crosses midnight
            return start1 >= start2 || end1 <= end2 || (start1 < end1 && end1 > start2)
        } else {
            // Neither crosses midnight - standard overlap check
            return start1 < end2 && start2 < end1
        }
    }

    /// Find all active schedules that would overlap with the given session
    private func findOverlappingSchedules(for session: ScheduleSession, excluding excludeID: UUID? = nil) -> [ScheduleSession] {
        return activeSessions.filter { activeSession in
            // Don't compare with itself
            if let excludeID = excludeID, activeSession.id == excludeID {
                return false
            }
            if activeSession.id == session.id {
                return false
            }

            return schedulesOverlap(session, activeSession)
        }
    }

    // MARK: - Helpers

    private func binding(for session: ScheduleSession) -> Binding<Bool> {
        Binding<Bool>(
            get: { session.isEnabled },
            set: { newValue in
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    // If trying to enable, check for overlaps
                    if newValue {
                        let overlapping = findOverlappingSchedules(for: sessions[idx], excluding: sessions[idx].id)
                        if !overlapping.isEmpty {
                            // Show alert with overlap details
                            let conflictNames = overlapping.map { "\($0.name) (\($0.formattedTime))" }.joined(separator: ", ")
                            overlapAlertMessage = "Cannot enable this schedule. It overlaps with: \(conflictNames).\n\nDisable the conflicting schedule(s) first."
                            showOverlapAlert = true
                            return // Don't enable
                        }

                        applySchedule(sessions[idx])
                    } else {
                        removeSchedule(sessions[idx])
                    }

                    sessions[idx].isEnabled = newValue
                    saveSessions()

                    // Track analytics
                    AnalyticsManager.shared.trackScheduleToggled(name: sessions[idx].name, isEnabled: newValue)
                }
            }
        )
    }

    private func addFromIdea(_ idea: ScheduleIdea) {
        let session = idea.toSession()
        sessions.append(session)
        applySchedule(session)
        saveSessions()

        // Track analytics
        AnalyticsManager.shared.trackScheduleCreated(
            name: session.name,
            startTime: session.formattedTime.components(separatedBy: " - ").first ?? "",
            endTime: session.formattedTime.components(separatedBy: " - ").last ?? "",
            appsCount: session.blockedAppsCount
        )
    }

    private func deleteSession(_ session: ScheduleSession) {
        removeSchedule(session)
        sessions.removeAll { $0.id == session.id }
        saveSessions()

        // Track analytics
        AnalyticsManager.shared.trackScheduleDeleted(name: session.name)
    }

    private func applySchedule(_ session: ScheduleSession) {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: session.startHour, minute: session.startMinute)) ?? Date()
        let end = calendar.date(from: DateComponents(hour: session.endHour, minute: session.endMinute)) ?? Date()
        screenTimeManager.setupDisconnectSchedule(
            type: session.name,
            startTime: start,
            endTime: end,
            blockedAppsData: session.blockedAppTokensData,
            scheduleID: session.id.uuidString
        )
    }

    private func removeSchedule(_ session: ScheduleSession) {
        screenTimeManager.stopSchedule(id: session.id.uuidString)
    }

    // MARK: - Persistence

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "beyou_scheduled_sessions")
        }
    }

    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "beyou_scheduled_sessions"),
           let decoded = try? JSONDecoder().decode([ScheduleSession].self, from: data) {
            sessions = decoded
        }
    }
}

// MARK: - New Schedule Session Sheet

@available(iOS 16.0, *)
struct NewScheduleSessionSheet: View {
    @Binding var sessions: [ScheduleSession]
    let screenTimeManager: ScreenTimeManager
    let onOverlapDetected: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedEmoji = "⏰"
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
    @State private var selectedDays: Set<Int> = [] // empty = every day
    @State private var selectedApps = FamilyActivitySelection()
    @State private var isPickerPresented = false

    private let emojiOptions = ["⏰", "🌅", "🌙", "🧠", "🍽", "📚", "🏖", "💪", "🧘", "🎯", "🔒", "☕️"]
    private let dayLabels = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count
    }

    // MARK: - Overlap Detection Helpers

    private func schedulesOverlap(_ session1: ScheduleSession, _ session2: ScheduleSession) -> Bool {
        if !session1.daysActive.isEmpty && !session2.daysActive.isEmpty {
            let daysOverlap = !session1.daysActive.isDisjoint(with: session2.daysActive)
            if !daysOverlap {
                return false
            }
        }

        return timeRangesOverlap(
            start1: session1.startHour * 60 + session1.startMinute,
            end1: session1.endHour * 60 + session1.endMinute,
            start2: session2.startHour * 60 + session2.startMinute,
            end2: session2.endHour * 60 + session2.endMinute
        )
    }

    private func timeRangesOverlap(start1: Int, end1: Int, start2: Int, end2: Int) -> Bool {
        let overnight1 = end1 < start1
        let overnight2 = end2 < start2

        if overnight1 && overnight2 {
            return true
        } else if overnight1 {
            return start2 >= start1 || end2 <= end1 || (start2 < end2 && end2 > start1)
        } else if overnight2 {
            return start1 >= start2 || end1 <= end2 || (start1 < end1 && end1 > start2)
        } else {
            return start1 < end2 && start2 < end1
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F8F8F8").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session Name")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            TextField("e.g. Morning Focus", text: $name)
                                .font(.system(size: 16))
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                                )
                        }

                        // Emoji Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                                ForEach(emojiOptions, id: \.self) { emoji in
                                    Button(action: { selectedEmoji = emoji }) {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 50, height: 50)
                                            .background(
                                                Circle()
                                                    .fill(selectedEmoji == emoji ? Color(hex: "1A1A1A").opacity(0.1) : Color.white)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedEmoji == emoji ? Color(hex: "1A1A1A") : Color(hex: "E0E0E0"), lineWidth: selectedEmoji == emoji ? 2 : 1)
                                            )
                                    }
                                }
                            }
                        }

                        // Time Pickers
                        VStack(spacing: 16) {
                            HStack {
                                Text("Start Time")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                                Spacer()
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(12)

                            HStack {
                                Text("End Time")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                                Spacer()
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(12)
                        }

                        // Days
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repeat")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            HStack(spacing: 8) {
                                ForEach(dayLabels, id: \.0) { day, label in
                                    Button(action: {
                                        if selectedDays.contains(day) {
                                            selectedDays.remove(day)
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    }) {
                                        Text(label)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(selectedDays.contains(day) ? .white : Color(hex: "1A1A1A"))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle()
                                                    .fill(selectedDays.contains(day) ? Color(hex: "1A1A1A") : Color.white)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(hex: "E0E0E0"), lineWidth: selectedDays.contains(day) ? 0 : 1)
                                            )
                                    }
                                }
                            }

                            Text(selectedDays.isEmpty ? "Every day" : "")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "999999"))
                        }

                        // Blocked Apps
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Blocked Apps")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Button(action: { isPickerPresented = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedAppsCount > 0 ? Color(hex: "1A1A1A") : Color(hex: "999999"))

                                    Text(selectedAppsCount > 0 ? "\(selectedAppsCount) app\(selectedAppsCount == 1 ? "" : "s") selected" : "Select apps to block")
                                        .font(.system(size: 15))
                                        .foregroundColor(selectedAppsCount > 0 ? Color(hex: "1A1A1A") : Color(hex: "999999"))

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(hex: "CCCCCC"))
                                }
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text("Choose which apps will be blocked during this session")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "999999"))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "999999"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveSession() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canSave ? Color(hex: "1A1A1A") : Color(hex: "CCCCCC"))
                        .disabled(!canSave)
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selectedApps)
        }
    }

    private func saveSession() {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        // Encode selected apps
        let blockedAppsData = try? JSONEncoder().encode(selectedApps)

        let session = ScheduleSession(
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: selectedEmoji,
            startHour: startComponents.hour ?? 9,
            startMinute: startComponents.minute ?? 0,
            endHour: endComponents.hour ?? 17,
            endMinute: endComponents.minute ?? 0,
            isEnabled: true,
            category: .schedule,
            daysActive: selectedDays,
            blockedAppTokensData: blockedAppsData
        )

        // Check for overlaps with active schedules
        let activeSchedules = sessions.filter { $0.isEnabled }
        let overlapping = activeSchedules.filter { schedulesOverlap(session, $0) }

        if !overlapping.isEmpty {
            let conflictNames = overlapping.map { "\($0.name) (\($0.formattedTime))" }.joined(separator: ", ")
            onOverlapDetected("Cannot create this schedule as enabled. It overlaps with: \(conflictNames).\n\nThe schedule will be created but disabled. You can enable it after disabling the conflicting schedule(s).")

            // Create the session but keep it disabled
            var disabledSession = session
            disabledSession.isEnabled = false
            sessions.append(disabledSession)

            // Persist
            if let data = try? JSONEncoder().encode(sessions) {
                UserDefaults.standard.set(data, forKey: "beyou_scheduled_sessions")
            }

            dismiss()
            return
        }

        sessions.append(session)

        // Track analytics
        AnalyticsManager.shared.trackScheduleCreated(
            name: session.name,
            startTime: session.formattedTime.components(separatedBy: " - ").first ?? "",
            endTime: session.formattedTime.components(separatedBy: " - ").last ?? "",
            appsCount: session.blockedAppsCount
        )

        // Apply schedule via ScreenTimeManager
        let start = calendar.date(from: DateComponents(hour: session.startHour, minute: session.startMinute)) ?? Date()
        let end = calendar.date(from: DateComponents(hour: session.endHour, minute: session.endMinute)) ?? Date()
        screenTimeManager.setupDisconnectSchedule(
            type: session.name,
            startTime: start,
            endTime: end,
            blockedAppsData: blockedAppsData,
            scheduleID: session.id.uuidString
        )

        // Persist
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "beyou_scheduled_sessions")
        }

        dismiss()
    }
}

// MARK: - Edit Schedule Session Sheet

@available(iOS 16.0, *)
struct EditScheduleSessionSheet: View {
    @Binding var sessions: [ScheduleSession]
    let session: ScheduleSession
    let wasEnabled: Bool
    let screenTimeManager: ScreenTimeManager
    let onOverlapDetected: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedEmoji = "⏰"
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var selectedDays: Set<Int> = []
    @State private var selectedApps = FamilyActivitySelection()
    @State private var isPickerPresented = false

    private let emojiOptions = ["⏰", "🌅", "🌙", "🧠", "🍽", "📚", "🏖", "💪", "🧘", "🎯", "🔒", "☕️"]
    private let dayLabels = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count
    }

    // MARK: - Overlap Detection Helpers

    private func schedulesOverlap(_ session1: ScheduleSession, _ session2: ScheduleSession) -> Bool {
        if !session1.daysActive.isEmpty && !session2.daysActive.isEmpty {
            let daysOverlap = !session1.daysActive.isDisjoint(with: session2.daysActive)
            if !daysOverlap {
                return false
            }
        }

        return timeRangesOverlap(
            start1: session1.startHour * 60 + session1.startMinute,
            end1: session1.endHour * 60 + session1.endMinute,
            start2: session2.startHour * 60 + session2.startMinute,
            end2: session2.endHour * 60 + session2.endMinute
        )
    }

    private func timeRangesOverlap(start1: Int, end1: Int, start2: Int, end2: Int) -> Bool {
        let overnight1 = end1 < start1
        let overnight2 = end2 < start2

        if overnight1 && overnight2 {
            return true
        } else if overnight1 {
            return start2 >= start1 || end2 <= end1 || (start2 < end2 && end2 > start1)
        } else if overnight2 {
            return start1 >= start2 || end1 <= end2 || (start1 < end1 && end1 > start2)
        } else {
            return start1 < end2 && start2 < end1
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F8F8F8").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session Name")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            TextField("e.g. Morning Focus", text: $name)
                                .font(.system(size: 16))
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                                )
                        }

                        // Emoji Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                                ForEach(emojiOptions, id: \.self) { emoji in
                                    Button(action: { selectedEmoji = emoji }) {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 50, height: 50)
                                            .background(
                                                Circle()
                                                    .fill(selectedEmoji == emoji ? Color(hex: "1A1A1A").opacity(0.1) : Color.white)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedEmoji == emoji ? Color(hex: "1A1A1A") : Color(hex: "E0E0E0"), lineWidth: selectedEmoji == emoji ? 2 : 1)
                                            )
                                    }
                                }
                            }
                        }

                        // Time Pickers
                        VStack(spacing: 16) {
                            HStack {
                                Text("Start Time")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                                Spacer()
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(12)

                            HStack {
                                Text("End Time")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                                Spacer()
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(12)
                        }

                        // Days
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repeat")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            HStack(spacing: 8) {
                                ForEach(dayLabels, id: \.0) { day, label in
                                    Button(action: {
                                        if selectedDays.contains(day) {
                                            selectedDays.remove(day)
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    }) {
                                        Text(label)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(selectedDays.contains(day) ? .white : Color(hex: "1A1A1A"))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle()
                                                    .fill(selectedDays.contains(day) ? Color(hex: "1A1A1A") : Color.white)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(hex: "E0E0E0"), lineWidth: selectedDays.contains(day) ? 0 : 1)
                                            )
                                    }
                                }
                            }

                            Text(selectedDays.isEmpty ? "Every day" : "")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "999999"))
                        }

                        // Blocked Apps
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Blocked Apps")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Button(action: { isPickerPresented = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedAppsCount > 0 ? Color(hex: "1A1A1A") : Color(hex: "999999"))

                                    Text(selectedAppsCount > 0 ? "\(selectedAppsCount) app\(selectedAppsCount == 1 ? "" : "s") selected" : "Select apps to block")
                                        .font(.system(size: 15))
                                        .foregroundColor(selectedAppsCount > 0 ? Color(hex: "1A1A1A") : Color(hex: "999999"))

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(hex: "CCCCCC"))
                                }
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text("Choose which apps will be blocked during this session")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "999999"))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Re-enable with original settings if it was active
                        if wasEnabled, let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                            sessions[idx].isEnabled = true
                            reapplySchedule(sessions[idx])
                            persistSessions()
                        }
                        dismiss()
                    }
                        .foregroundColor(Color(hex: "999999"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canSave ? Color(hex: "1A1A1A") : Color(hex: "CCCCCC"))
                        .disabled(!canSave)
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selectedApps)
            .onAppear {
                loadSessionData()
            }
        }
    }

    private func loadSessionData() {
        // Load existing session data
        name = session.name
        selectedEmoji = session.emoji
        selectedDays = session.daysActive

        // Create dates from hours/minutes
        let calendar = Calendar.current
        startTime = calendar.date(from: DateComponents(hour: session.startHour, minute: session.startMinute)) ?? Date()
        endTime = calendar.date(from: DateComponents(hour: session.endHour, minute: session.endMinute)) ?? Date()

        // Load blocked apps
        if let data = session.blockedAppTokensData,
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selectedApps = decoded
        }
    }

    private func saveChanges() {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            dismiss()
            return
        }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        // Encode selected apps
        let blockedAppsData = try? JSONEncoder().encode(selectedApps)

        // Create updated session object
        var updatedSession = sessions[index]
        updatedSession.name = name.trimmingCharacters(in: .whitespaces)
        updatedSession.emoji = selectedEmoji
        updatedSession.startHour = startComponents.hour ?? 9
        updatedSession.startMinute = startComponents.minute ?? 0
        updatedSession.endHour = endComponents.hour ?? 17
        updatedSession.endMinute = endComponents.minute ?? 0
        updatedSession.daysActive = selectedDays
        updatedSession.blockedAppTokensData = blockedAppsData

        // If it was enabled, check for overlaps before re-enabling
        if wasEnabled {
            let activeSchedules = sessions.filter { $0.isEnabled && $0.id != session.id }
            let overlapping = activeSchedules.filter { schedulesOverlap(updatedSession, $0) }

            if !overlapping.isEmpty {
                let conflictNames = overlapping.map { "\($0.name) (\($0.formattedTime))" }.joined(separator: ", ")
                onOverlapDetected("These changes would overlap with: \(conflictNames).\n\nYour original schedule has been restored.")

                // Restore original settings and re-enable
                sessions[index].isEnabled = true
                reapplySchedule(sessions[index])
                persistSessions()
                dismiss()
                return
            }

            // No overlaps — re-enable with new settings
            updatedSession.isEnabled = true
            sessions[index] = updatedSession
            reapplySchedule(sessions[index])
        } else {
            // Was disabled, keep it disabled
            sessions[index] = updatedSession
        }

        persistSessions()
        dismiss()
    }

    private func reapplySchedule(_ session: ScheduleSession) {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(hour: session.startHour, minute: session.startMinute)) ?? Date()
        let end = calendar.date(from: DateComponents(hour: session.endHour, minute: session.endMinute)) ?? Date()
        screenTimeManager.setupDisconnectSchedule(
            type: session.name,
            startTime: start,
            endTime: end,
            blockedAppsData: session.blockedAppTokensData,
            scheduleID: session.id.uuidString
        )
    }

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "beyou_scheduled_sessions")
        }
    }
}

// MARK: - Swipe to Delete Wrapper

struct SwipeToDeleteWrapper<Content: View>: View {
    let onDelete: () -> Void
    let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var showDelete = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 60)
                }
                .frame(width: 60)
            }
            .frame(maxHeight: .infinity)
            .background(Color(hex: "EF4444"))
            .cornerRadius(14)

            // Main content
            content()
                .offset(x: offset)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onChanged { value in
                            // Only respond to horizontal swipes
                            if abs(value.translation.width) > abs(value.translation.height) {
                                if value.translation.width < 0 {
                                    offset = max(value.translation.width, -70)
                                } else if showDelete {
                                    offset = min(0, -70 + value.translation.width)
                                }
                            }
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.2)) {
                                if value.translation.width < -35 && abs(value.translation.width) > abs(value.translation.height) {
                                    offset = -70
                                    showDelete = true
                                } else {
                                    offset = 0
                                    showDelete = false
                                }
                            }
                        }
                )
        }
    }
}
