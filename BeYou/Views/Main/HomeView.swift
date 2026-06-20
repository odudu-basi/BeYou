import SwiftUI
import FamilyControls
import ManagedSettings

@available(iOS 16.0, *)
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var showManageOptions = false
    @State private var isPickerPresented = false

    // Daily challenges state
    @AppStorage("dailyChallenges") private var dailyChallengesData: Data = Data()
    @AppStorage("seededChallenges") private var seededChallengesData: Data = Data()
    @AppStorage("seededChallengesDate") private var seededChallengesDateString: String = ""
    @AppStorage("lastChallengeResetDate") private var lastResetDateString: String = ""
    @State private var challenges: [DailyChallenge] = []
    @State private var seededChallenges: [DailyChallenge] = []
    @State private var showStreakDetail = false
    @State private var showAddChallenge = false
    @State private var activeBlockingSessions: [ScheduleSession] = []
    @State private var showStopSessionConfirmation: ScheduleSession?

    private var disciplineScore: Int {
        appState.disciplineScore.score
    }

    private var progressPercentage: CGFloat {
        CGFloat(disciplineScore) / 100.0
    }

    private var userName: String {
        appState.onboardingData.name ?? "there"
    }

    private var currentStreak: Int {
        appState.appUsageStats.currentStreak
    }

    private var streakMessage: String {
        switch currentStreak {
        case 0: return "Start your streak today!"
        case 1: return "1 day strong!"
        case 2...6: return "\(currentStreak) days going!"
        case 7...13: return "\(currentStreak) days! Keep it up!"
        case 14...29: return "\(currentStreak) days! On fire!"
        default: return "\(currentStreak) days! Unstoppable!"
        }
    }

    var body: some View {
        NavigationStack {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header with streak badge
                    HStack {
                        // Streak badge (tappable)
                        Button(action: { showStreakDetail = true }) {
                            HStack(spacing: 5) {
                                Text("🔥")
                                    .font(.system(size: 18))

                                Text("\(currentStreak)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(currentStreak > 0 ? Color(hex: "FF6B35") : Color(hex: "CCCCCC"))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(currentStreak > 0 ? Color(hex: "FFF3ED") : Color(hex: "F5F5F5"))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(currentStreak > 0 ? Color(hex: "FF6B35").opacity(0.2) : Color(hex: "E8E8E8"), lineWidth: 1)
                            )
                        }
                        .buttonStyle(HapticButtonStyle())

                        Spacer()

                        Text("Discipline Score")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .tracking(-0.3)

                        Spacer()

                        // Settings gear icon
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "999999"))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(HapticButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // Score Section
                    VStack(spacing: 24) {
                        // Logo (tilted)
                        Image("be-you-icon")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(20)
                            .rotationEffect(.degrees(-5))

                        // Score
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(disciplineScore)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-1)

                            Text("/100")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(Color(hex: "999999"))
                        }

                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(hex: "E0E0E0"))
                                    .frame(height: 8)
                                    .cornerRadius(4)

                                Rectangle()
                                    .fill(Color(hex: "1A1A1A"))
                                    .frame(width: geometry.size.width * progressPercentage, height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                        .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 40)

                    // Active Blocking Sessions
                    if !activeBlockingSessions.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(activeBlockingSessions) { session in
                                ActiveBlockingSessionCard(
                                    session: session,
                                    onStop: {
                                        showStopSessionConfirmation = session
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }

                    // Daily Challenges Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Daily Challenges")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Spacer()

                            // Completed count
                            let allChallenges = seededChallenges + challenges
                            let completedCount = allChallenges.filter { $0.isCompleted }.count
                            Text("\(completedCount)/\(allChallenges.count)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(completedCount == allChallenges.count ? Color(hex: "10B981") : Color(hex: "999999"))
                        }

                        // Checklist
                        VStack(spacing: 12) {
                            // Seeded daily challenges (not deletable)
                            ForEach(seededChallenges.indices, id: \.self) { index in
                                ChallengeChecklistItem(
                                    challenge: seededChallenges[index],
                                    onToggle: {
                                        toggleSeededChallenge(at: index)
                                    }
                                )
                            }

                            // Custom challenges (deletable)
                            ForEach(challenges.indices, id: \.self) { index in
                                ChallengeChecklistItem(
                                    challenge: challenges[index],
                                    onToggle: {
                                        toggleChallenge(at: index)
                                    },
                                    onDelete: {
                                        deleteChallenge(at: index)
                                    }
                                )
                            }

                            // Add challenge row
                            Button(action: { showAddChallenge = true }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color(hex: "E2E8F0"), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color(hex: "CCCCCC"))
                                    }

                                    Text("Add challenge")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "CCCCCC"))

                                    Spacer()
                                }
                                .padding(16)
                                .background(Color(hex: "F8F8F8").opacity(0.5))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E2E8F0"), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                                )
                            }
                            .buttonStyle(HapticButtonStyle())
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)

                    // Bottom spacer for tab bar
                    Spacer()
                        .frame(height: 120)
                }
            }
        }
        .confirmationDialog("Manage Blocked Apps", isPresented: $showManageOptions, titleVisibility: .visible) {
            Button("View Blocked Apps") {
                // TODO: View blocked apps
            }

            Button("Select New Apps") {
                isPickerPresented = true
            }

            Button("Remove All Blocks", role: .destructive) {
                screenTimeManager.unblockAllApps()
            }

            Button("Cancel", role: .cancel) {}
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $screenTimeManager.activitySelection)
        .onChange(of: screenTimeManager.activitySelection) { _ in
            screenTimeManager.blockSelectedApps()
        }
        .sheet(isPresented: $showStreakDetail) {
            StreakDetailSheet(appState: appState)
        }
        .alert(
            "Stop Blocking Session?",
            isPresented: Binding(
                get: { showStopSessionConfirmation != nil },
                set: { if !$0 { showStopSessionConfirmation = nil } }
            )
        ) {
            Button("OK", role: .destructive) {
                if let session = showStopSessionConfirmation {
                    stopBlockingSession(session)
                }
            }
            Button("Cancel", role: .cancel) {
                showStopSessionConfirmation = nil
            }
        } message: {
            Text("This will stop the \"\(showStopSessionConfirmation?.name ?? "")\" blocking session and unblock all apps in it.")
        }
        .sheet(isPresented: $showAddChallenge) {
            AddChallengeSheet { name, emoji, affectsDiscipline in
                addChallenge(name: name, emoji: emoji, affectsDiscipline: affectsDiscipline)
            }
        }
        .onAppear {
            loadChallenges()
            checkDailyReset()
            loadActiveBlockingSessions()
            updateDisciplineChallengeBonus()
        }
        .navigationBarHidden(true)
        }
    }

    // MARK: - Daily Challenge Functions

    private func loadChallenges() {
        // Load custom challenges
        if let decoded = try? JSONDecoder().decode([DailyChallenge].self, from: dailyChallengesData) {
            challenges = decoded
        } else {
            challenges = []
            saveChallenges()
        }

        // Load or generate seeded daily challenges
        loadSeededChallenges()
    }

    private func loadSeededChallenges() {
        let formatter = ISO8601DateFormatter()
        let today = Calendar.current.startOfDay(for: Date())
        let todayString = formatter.string(from: today)

        // If seeded challenges are from today, load them
        if seededChallengesDateString == todayString,
           let decoded = try? JSONDecoder().decode([DailyChallenge].self, from: seededChallengesData) {
            seededChallenges = decoded
            return
        }

        // Generate new seeded challenges for today
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: today)
        let seed = (components.year ?? 2026) * 10000 + (components.month ?? 1) * 100 + (components.day ?? 1)

        var picks: [Int] = []
        var s = seed
        while picks.count < 3 {
            s = (s &* 16807) % 2147483647
            let idx = abs(s) % seededChallengePool.count
            if !picks.contains(idx) {
                picks.append(idx)
            }
        }

        seededChallenges = picks.map { idx in
            let item = seededChallengePool[idx]
            return DailyChallenge(
                id: "seeded-\(idx)",
                emoji: item.emoji,
                title: item.title,
                isCompleted: false,
                affectsDiscipline: true,
                isDefault: true
            )
        }

        // Save
        seededChallengesDateString = todayString
        if let encoded = try? JSONEncoder().encode(seededChallenges) {
            seededChallengesData = encoded
        }
    }

    private func saveChallenges() {
        if let encoded = try? JSONEncoder().encode(challenges) {
            dailyChallengesData = encoded
        }
    }

    private func toggleSeededChallenge(at index: Int) {
        seededChallenges[index].isCompleted.toggle()
        if let encoded = try? JSONEncoder().encode(seededChallenges) {
            seededChallengesData = encoded
        }

        if seededChallenges[index].isCompleted {
            AnalyticsManager.shared.trackChallengeCompleted(name: seededChallenges[index].title)
        }

        updateDisciplineChallengeBonus()
    }

    private func toggleChallenge(at index: Int) {
        challenges[index].isCompleted.toggle()
        saveChallenges()

        if challenges[index].isCompleted {
            AnalyticsManager.shared.trackChallengeCompleted(name: challenges[index].title)
        }

        if challenges[index].affectsDiscipline {
            updateDisciplineChallengeBonus()
        }
    }

    private func addChallenge(name: String, emoji: String, affectsDiscipline: Bool) {
        let challenge = DailyChallenge(
            id: UUID().uuidString,
            emoji: emoji,
            title: name,
            isCompleted: false,
            affectsDiscipline: affectsDiscipline,
            isDefault: false
        )
        challenges.append(challenge)
        saveChallenges()

        // Track challenge creation
        AnalyticsManager.shared.trackChallengeCreated(name: name, affectsDiscipline: affectsDiscipline)
    }

    private func deleteChallenge(at index: Int) {
        let wasAffecting = challenges[index].affectsDiscipline && challenges[index].isCompleted
        challenges.remove(at: index)
        saveChallenges()
        if wasAffecting {
            updateDisciplineChallengeBonus()
        }
    }

    private func updateDisciplineChallengeBonus() {
        let seededCount = seededChallenges.filter { $0.isCompleted }.count
        let customCount = challenges.filter { $0.affectsDiscipline && $0.isCompleted }.count
        let bonus = Double(seededCount + customCount) * 0.5
        appState.challengeDisciplineBonus = bonus
    }

    private func loadActiveBlockingSessions() {
        guard let data = UserDefaults.standard.data(forKey: "beyou_scheduled_sessions"),
              let sessions = try? JSONDecoder().decode([ScheduleSession].self, from: data) else {
            activeBlockingSessions = []
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now) // 1=Sun

        activeBlockingSessions = sessions.filter { session in
            guard session.isEnabled else { return false }

            // Check if today is an active day
            if !session.daysActive.isEmpty && !session.daysActive.contains(currentWeekday) {
                return false
            }

            // Check if current time is within the schedule
            let startMinutes = session.startHour * 60 + session.startMinute
            let endMinutes = session.endHour * 60 + session.endMinute

            if endMinutes > startMinutes {
                // Normal schedule (doesn't cross midnight)
                return currentMinutes >= startMinutes && currentMinutes < endMinutes
            } else {
                // Overnight schedule (crosses midnight)
                return currentMinutes >= startMinutes || currentMinutes < endMinutes
            }
        }
    }

    private func stopBlockingSession(_ session: ScheduleSession) {
        // Stop the schedule in ScreenTimeManager
        screenTimeManager.stopSchedule(id: session.id.uuidString)

        // Disable the session in saved data
        if var sessions = try? JSONDecoder().decode(
            [ScheduleSession].self,
            from: UserDefaults.standard.data(forKey: "beyou_scheduled_sessions") ?? Data()
        ) {
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx].isEnabled = false
                if let encoded = try? JSONEncoder().encode(sessions) {
                    UserDefaults.standard.set(encoded, forKey: "beyou_scheduled_sessions")
                }
            }
        }

        // Clear the instructions flag in case it was set
        SharedDataManager.shared.saveScheduleShowInstructions(false)

        // Remove from active schedule tracking in App Groups
        let scheduleKey = "schedule_\(session.id.uuidString)"
        SharedDataManager.shared.removeActiveSchedule(scheduleKey)
        SharedDataManager.shared.removeActiveScheduleTokensForSchedule(scheduleKey)

        // Remove from active list
        activeBlockingSessions.removeAll { $0.id == session.id }

        showStopSessionConfirmation = nil
    }

    private func checkDailyReset() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()

        if let lastResetDate = formatter.date(from: lastResetDateString) {
            let lastReset = calendar.startOfDay(for: lastResetDate)

            if today > lastReset {
                // Reset custom challenges
                for index in challenges.indices {
                    challenges[index].isCompleted = false
                }
                saveChallenges()

                // Regenerate seeded challenges for the new day
                loadSeededChallenges()

                lastResetDateString = formatter.string(from: today)
            }
        } else {
            lastResetDateString = formatter.string(from: today)
        }
    }
}

// MARK: - Daily Challenge Models

struct DailyChallenge: Codable, Identifiable {
    let id: String
    let emoji: String
    let title: String
    var isCompleted: Bool
    var affectsDiscipline: Bool
    var isDefault: Bool

    // Coding keys with defaults for backward compatibility
    enum CodingKeys: String, CodingKey {
        case id, emoji, title, isCompleted, affectsDiscipline, isDefault
    }

    init(id: String, emoji: String, title: String, isCompleted: Bool, affectsDiscipline: Bool = false, isDefault: Bool = true) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.isCompleted = isCompleted
        self.affectsDiscipline = affectsDiscipline
        self.isDefault = isDefault
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        emoji = try container.decode(String.self, forKey: .emoji)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        affectsDiscipline = try container.decodeIfPresent(Bool.self, forKey: .affectsDiscipline) ?? false
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? true
    }
}

// MARK: - Seeded Challenge Pool

let seededChallengePool: [(emoji: String, title: String)] = [
    ("🚶", "Go for a 15-minute walk"),
    ("📚", "Read a book for 20 minutes"),
    ("💧", "Drink 3L of water"),
    ("📵", "No phone for the first hour after waking"),
    ("📝", "Journal for 10 minutes"),
    ("🧘", "Meditate for 5 minutes"),
    ("💪", "Do a 10-minute workout"),
    ("🍳", "Cook a meal from scratch"),
    ("📞", "Call or text a friend or family member"),
    ("🛏️", "Make your bed"),
    ("🚫", "No social media before noon"),
    ("☀️", "Go outside and get sunlight"),
    ("🤸", "Stretch for 10 minutes"),
    ("🎧", "Listen to a podcast instead of scrolling"),
    ("🙏", "Write down 3 things you're grateful for"),
    ("🚿", "Take a cold shower"),
    ("🧹", "Clean or organize one area of your space"),
    ("😊", "Compliment someone genuinely"),
    ("🌙", "No screen time 1 hour before bed"),
    ("🧠", "Learn something new for 15 minutes"),
]

// MARK: - Challenge Checklist Item

struct ChallengeChecklistItem: View {
    let challenge: DailyChallenge
    let onToggle: () -> Void
    var onDelete: (() -> Void)?

    @State private var offset: CGFloat = 0
    @State private var showDelete = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            if onDelete != nil {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            onDelete?()
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: 60, maxHeight: .infinity)
                    }
                    .frame(width: 60)
                }
                .frame(maxHeight: .infinity)
                .background(Color(hex: "EF4444"))
                .cornerRadius(12)
            }

            // Main content
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    // Checkbox
                    ZStack {
                        Circle()
                            .stroke(challenge.isCompleted ? Color(hex: "10B981") : Color(hex: "E2E8F0"), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if challenge.isCompleted {
                            Circle()
                                .fill(Color(hex: "10B981"))
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    // Emoji and title
                    HStack(spacing: 10) {
                        Text(challenge.emoji)
                            .font(.system(size: 20))

                        Text(challenge.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(challenge.isCompleted ? Color(hex: "999999") : Color(hex: "1A1A1A"))
                            .strikethrough(challenge.isCompleted, color: Color(hex: "999999"))
                    }

                    Spacer()

                    // Discipline badge
                    if challenge.affectsDiscipline {
                        Text("+0.5")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(challenge.isCompleted ? Color(hex: "10B981") : Color(hex: "999999"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(challenge.isCompleted ? Color(hex: "10B981").opacity(0.1) : Color(hex: "F0F0F0"))
                            )
                    }
                }
                .padding(16)
                .background(Color(hex: "F8F8F8"))
                .cornerRadius(12)
            }
            .buttonStyle(HapticButtonStyle())
            .offset(x: offset)
            .simultaneousGesture(
                onDelete != nil ?
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
                : nil
            )
        }
    }
}

// MARK: - Add Challenge Sheet

struct AddChallengeSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var challengeName: String = ""
    @State private var selectedEmoji: String = "⭐"
    @State private var affectsDiscipline: Bool = false

    let onAdd: (String, String, Bool) -> Void

    private let emojiOptions: [(category: String, emojis: [String])] = [
        ("Fitness", ["🏃", "💪", "🧘", "🚴", "🏋️", "⚽", "🏊", "🥊"]),
        ("Wellness", ["💧", "😴", "🧠", "💊", "🫁", "🌿", "🍎", "🥗"]),
        ("Productivity", ["📚", "✍️", "💻", "📝", "🎯", "⏰", "📅", "🗂️"]),
        ("Self-Care", ["🦷", "🧴", "🛁", "👔", "🧹", "🪞", "💅", "🧺"]),
        ("Mindfulness", ["🙏", "📿", "🕯️", "🌅", "☀️", "🌙", "⭐", "🎵"])
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F8F8F8").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Preview
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .stroke(Color(hex: "E2E8F0"), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }

                            HStack(spacing: 10) {
                                Text(selectedEmoji)
                                    .font(.system(size: 20))

                                Text(challengeName.isEmpty ? "Challenge name" : challengeName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(challengeName.isEmpty ? Color(hex: "CCCCCC") : Color(hex: "1A1A1A"))
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CHALLENGE NAME")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "999999"))
                                .tracking(0.8)

                            TextField("e.g. Meditate for 10 minutes", text: $challengeName)
                                .font(.system(size: 16))
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        // Icon picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CHOOSE ICON")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "999999"))
                                .tracking(0.8)

                            VStack(spacing: 16) {
                                ForEach(emojiOptions, id: \.category) { section in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(section.category)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color(hex: "666666"))

                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                                            ForEach(section.emojis, id: \.self) { emoji in
                                                Button(action: { selectedEmoji = emoji }) {
                                                    Text(emoji)
                                                        .font(.system(size: 24))
                                                        .frame(width: 40, height: 40)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .fill(selectedEmoji == emoji ? Color(hex: "1A1A1A").opacity(0.1) : Color.clear)
                                                        )
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .stroke(selectedEmoji == emoji ? Color(hex: "1A1A1A") : Color.clear, lineWidth: 2)
                                                        )
                                                }
                                                .buttonStyle(HapticButtonStyle())
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        // Discipline toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DISCIPLINE SCORE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "999999"))
                                .tracking(0.8)

                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Affects Discipline Score")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "1A1A1A"))

                                    Text("Completing this adds +0.5 to your score")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "999999"))
                                }

                                Spacer()

                                Toggle("", isOn: $affectsDiscipline)
                                    .tint(Color(hex: "1A1A1A"))
                                    .labelsHidden()
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        // Add button
                        Button(action: {
                            guard !challengeName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            onAdd(challengeName.trimmingCharacters(in: .whitespaces), selectedEmoji, affectsDiscipline)
                            dismiss()
                        }) {
                            Text("Add Challenge")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(challengeName.trimmingCharacters(in: .whitespaces).isEmpty ? Color(hex: "CCCCCC") : Color(hex: "1A1A1A"))
                                .cornerRadius(16)
                        }
                        .disabled(challengeName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 36)
                    }
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "999999"))
                            .frame(width: 32, height: 32)
                            .background(Color(hex: "F0F0F0"))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
}

// MARK: - Streak Detail Sheet

@available(iOS 16.0, *)
struct StreakDetailSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    private var overallStreak: Int {
        appState.appUsageStats.currentStreak
    }

    private var perAppIntentions: [String: IndividualAppIntention] {
        appState.onboardingData.appIntention.perAppIntentions
    }

    /// Resolves a token key like "app_-123..." to a display name like "Instagram"
    private func resolveDisplayName(_ key: String) -> String {
        guard key.hasPrefix("app_") else { return key }
        let mapping = SharedDataManager.shared.loadStoreKeyMapping()
        for (displayName, tokenKey) in mapping {
            if tokenKey == key { return displayName }
        }
        return key
    }

    /// Gets the streak for an app, checking both the key and resolved display name
    private func getStreak(for key: String) -> Int {
        // Check direct key first
        if let streak = appState.appUsageStats.currentStreakByApp[key], streak > 0 {
            return streak
        }
        // Check resolved display name
        let displayName = resolveDisplayName(key)
        if displayName != key {
            return appState.appUsageStats.currentStreakByApp[displayName] ?? 0
        }
        return 0
    }

    private var streakMessage: String {
        switch overallStreak {
        case 0: return "Start your streak today!"
        case 1: return "1 day strong!"
        case 2...6: return "\(overallStreak) days going!"
        case 7...13: return "\(overallStreak) days! Keep it up!"
        case 14...29: return "\(overallStreak) days! On fire!"
        default: return "\(overallStreak) days! Unstoppable!"
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "FFF8F2").ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "999999"))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "F0F0F0"))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Fire icon
                        Text("🔥")
                            .font(.system(size: 80))
                            .padding(.top, 20)

                        // Overall streak
                        VStack(spacing: 8) {
                            Text("\(overallStreak) day streak")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text(streakMessage)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "999999"))
                        }

                        // Per-app streaks
                        if !perAppIntentions.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Your app intention streaks")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "666666"))
                                    .padding(.horizontal, 4)

                                VStack(spacing: 10) {
                                    ForEach(Array(perAppIntentions.keys.sorted()), id: \.self) { key in
                                        let intention = perAppIntentions[key]!
                                        let streak = getStreak(for: key)
                                        let limit = intention.timesPerDay

                                        AppStreakRow(
                                            appName: intention.appName,
                                            tokenData: intention.appTokenData,
                                            streak: streak,
                                            limit: limit
                                        )
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - App Streak Row

@available(iOS 16.0, *)
struct AppStreakRow: View {
    let appName: String
    let tokenData: Data?
    let streak: Int
    let limit: Int

    // Generate a consistent color from app name
    private var appColor: Color {
        let colors = ["5B8DEF", "FF6B35", "10B981", "8B5CF6", "EC4899", "F59E0B", "6366F1", "EF4444"]
        let index = abs(appName.hashValue) % colors.count
        return Color(hex: colors[index])
    }

    private var initial: String {
        String(appName.prefix(1)).uppercased()
    }

    private var decodedToken: ApplicationToken? {
        guard let data = tokenData else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    var body: some View {
        HStack(spacing: 14) {
            // App icon
            if let token = decodedToken {
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(appColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Text(initial)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(appColor)
                }
            }

            // App info
            VStack(alignment: .leading, spacing: 3) {
                if appName.hasPrefix("app_"), let token = decodedToken {
                    Label(token)
                        .labelStyle(.titleOnly)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                } else {
                    Text(appName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }

                Text("Under \(limit) opens")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "999999"))
            }

            Spacer()

            // Streak count
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 18))

                Text("\(streak)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(streak > 0 ? Color(hex: "FF6B35") : Color(hex: "CCCCCC"))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
        )
    }
}

// MARK: - Active Blocking Session Card

@available(iOS 16.0, *)
struct ActiveBlockingSessionCard: View {
    let session: ScheduleSession
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Session emoji
            ZStack {
                Circle()
                    .fill(Color(hex: "FEE2E2"))
                    .frame(width: 44, height: 44)

                Text(session.emoji)
                    .font(.system(size: 22))
            }

            // Session info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "EF4444"))
                        .frame(width: 8, height: 8)

                    Text(session.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }

                Text(session.formattedTime)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "999999"))
            }

            Spacer()

            // Red stop button (recording-style square)
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "EF4444"))
                        .frame(width: 40, height: 40)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                }
            }
            .buttonStyle(HapticButtonStyle())
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "EF4444").opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color(hex: "EF4444").opacity(0.08), radius: 8, x: 0, y: 2)
    }
}
