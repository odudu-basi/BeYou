import SwiftUI

// MARK: - Morning Memory Model

struct MorningMemory: Codable, Identifiable {
    var id = UUID()
    var imageData: Data
    var date: Date
    var missionName: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Insights View

@available(iOS 16.0, *)
struct InsightsView: View {
    @AppStorage("badgesEarned") private var badgesEarned: Int = 0
    @AppStorage("showMorningMemories") private var showMorningMemories: Bool = true
    @State private var memories: [MorningMemory] = []
    @State private var selectedMemory: MorningMemory?
    @State private var showStreakCalendar = false
    @State private var streakCount: Int = 0
    @State private var streakDays: [Bool] = Array(repeating: false, count: 7) // S M T W T F S

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // Stats (computed from AlarmStatsStore on appear)
    @State private var avgWakeTimeFormatted: String = "—"
    @State private var avgResponseFormatted: String = "—"
    @State private var favoriteMission: String = "—"
    @State private var favoriteSound: String = "—"

    private func loadStats() {
        if let minutes = AlarmStatsStore.averageWakeMinutes {
            let hours = minutes / 60
            let mins = minutes % 60
            let h = hours % 12 == 0 ? 12 : hours % 12
            let period = hours < 12 ? "AM" : "PM"
            avgWakeTimeFormatted = "\(h):\(String(format: "%02d", mins)) \(period)"
        } else {
            avgWakeTimeFormatted = "—"
        }

        if let seconds = AlarmStatsStore.averageResponseSeconds {
            let m = seconds / 60
            let s = seconds % 60
            avgResponseFormatted = m > 0 ? "\(m)m \(s)s" : "\(s)s"
        } else {
            avgResponseFormatted = "—"
        }

        favoriteMission = AlarmStatsStore.favoriteMission ?? "—"
        favoriteSound = AlarmStatsStore.favoriteSound ?? "—"
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Text("Insights")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // STATS section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("STATS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "999999"))
                            .tracking(1)
                            .padding(.horizontal, 20)

                        // Day Streak card (full width)
                        VStack(spacing: 10) {
                            // Flame icon with number
                            ZStack {
                                Text("🔥")
                                    .font(.system(size: 40))

                                Text("\(streakCount)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(y: 3)
                            }

                            Text("Day Streak")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            // Weekly dots
                            HStack(spacing: 10) {
                                ForEach(0..<7, id: \.self) { index in
                                    ZStack {
                                        Circle()
                                            .fill(streakDays[index] ? Color(hex: "6C5CE7").opacity(0.15) : Color(hex: "E8E8E8"))
                                            .frame(width: 28, height: 28)

                                        if streakDays[index] {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(Color(hex: "6C5CE7"))
                                        } else {
                                            Text(dayLabels[index])
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Color(hex: "999999"))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 168)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                        .onTapGesture {
                            Haptics.tap()
                            AnalyticsManager.shared.trackStreakCalendarOpened()
                            showStreakCalendar = true
                        }
                        .padding(.horizontal, 20)

                        // Stats grid
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                statCell(icon: "sunrise.fill", label: "Avg Wake Time", value: avgWakeTimeFormatted)

                                Divider().frame(height: 60)

                                statCell(icon: "stopwatch.fill", label: "Avg Response", value: avgResponseFormatted)
                            }

                            Divider().padding(.horizontal, 16)

                            HStack(spacing: 0) {
                                statCell(icon: "camera.viewfinder", label: "Favorite Mission", value: favoriteMission)

                                Divider().frame(height: 60)

                                statCell(icon: "music.note", label: "Favorite Sound", value: favoriteSound)
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 20)
                    }

                    // MEMORIES section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MEMORIES")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "999999"))
                            .tracking(1)
                            .padding(.horizontal, 20)

                        // Morning memories header
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "999999"))
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "F0F0F0"))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Morning memories")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Text("Photos from your missions")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "999999"))
                            }

                            Spacer()

                            Toggle("", isOn: $showMorningMemories)
                                .labelsHidden()
                                .tint(Color(hex: "34C759"))
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 20)

                        // Photo grid
                        if showMorningMemories {
                            if memories.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color(hex: "CCCCCC"))

                                    Text("No memories yet")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "999999"))

                                    Text("Complete missions to capture your mornings")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "BBBBBB"))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                                .padding(.horizontal, 20)
                            } else {
                                let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

                                VStack(spacing: 0) {
                                    LazyVGrid(columns: columns, spacing: 4) {
                                        ForEach(memories) { memory in
                                            ZStack(alignment: .bottomLeading) {
                                                if let uiImage = UIImage(data: memory.imageData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(height: 120)
                                                        .clipped()
                                                }

                                                // Date label
                                                Text(memory.formattedDate)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color.black.opacity(0.5))
                                                    .cornerRadius(4)
                                                    .padding(6)
                                            }
                                            .frame(height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .contentShape(RoundedRectangle(cornerRadius: 12))
                                            .onTapGesture {
                                                Haptics.tap()
                                                AnalyticsManager.shared.trackMemoryViewed(mission: memory.missionName)
                                                selectedMemory = memory
                                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    delete(memory)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)

                                    // Clear all
                                    if !memories.isEmpty {
                                        Button(action: {
                                            AnalyticsManager.shared.trackMemoriesCleared(count: memories.count)
                                            memories.removeAll()
                                            saveMemories()
                                        }) {
                                            Text("Clear all")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "999999"))
                                        }
                                        .padding(.top, 8)
                                    }
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 120)
                }
            }
        }
        .onAppear {
            loadMemories()
            loadStreakDays()
            loadStats()
            streakCount = AlarmCompletionStore.currentStreak()
            AnalyticsManager.shared.trackInsightsViewed()
        }
        .fullScreenCover(item: $selectedMemory) { memory in
            MemoryDetailView(memory: memory) {
                delete(memory)
                selectedMemory = nil
            }
        }
        .sheet(isPresented: $showStreakCalendar) {
            StreakCalendarView(completedDays: AlarmCompletionStore.load())
        }
    }

    // MARK: - Stat Cell

    private func statCell(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "999999"))

                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "999999"))
            }

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    // MARK: - Persistence

    private func loadMemories() {
        if let data = UserDefaults.standard.data(forKey: "morningMemories"),
           let decoded = try? JSONDecoder().decode([MorningMemory].self, from: data) {
            memories = decoded
        }
    }

    private func saveMemories() {
        if let encoded = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(encoded, forKey: "morningMemories")
        }
    }

    private func delete(_ memory: MorningMemory) {
        AnalyticsManager.shared.trackMemoryDeleted(mission: memory.missionName)
        memories.removeAll { $0.id == memory.id }
        saveMemories()
    }

    private func loadStreakDays() {
        // Same source as the Home weekly tracker: which days this week had a completed mission.
        let completed = AlarmCompletionStore.load()
        let cal = Calendar.current
        let today = Date()
        let currentWeekday = cal.component(.weekday, from: today) - 1 // 0 = Sunday

        var result = Array(repeating: false, count: 7)
        for index in 0...currentWeekday {
            let daysAgo = currentWeekday - index
            if let date = cal.date(byAdding: .day, value: -daysAgo, to: today) {
                result[index] = completed.contains(Self.dateFormatter.string(from: date))
            }
        }
        streakDays = result
    }
}
