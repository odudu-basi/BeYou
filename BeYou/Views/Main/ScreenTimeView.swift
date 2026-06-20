import SwiftUI
import FamilyControls
import ManagedSettings

// MARK: - Per-App Open Item (for ForEach)

struct AppOpenItem: Identifiable {
    let id: String // app name
    let name: String
    let opens: Int
    let limit: Int
    let sessionMinutes: Int
    let tokenData: Data?
}

// MARK: - Per-App Snapshot for Historical Records

struct AppOpenSnapshot: Codable {
    var opens: Int
    var limit: Int
    var sessionMinutes: Int
    var tokenData: Data? // Encoded ApplicationToken for real icon display

    // Backward compat: old snapshots won't have sessionMinutes
    init(opens: Int, limit: Int, sessionMinutes: Int = 5, tokenData: Data? = nil) {
        self.opens = opens
        self.limit = limit
        self.sessionMinutes = sessionMinutes
        self.tokenData = tokenData
    }
}

// MARK: - Weekly History Model

struct DailySnapshot: Codable {
    let date: Date
    var disciplineScore: Int
    var breakthroughsByApp: [String: Int]
    var totalBreakthroughs: Int
    var appOpenSnapshots: [String: AppOpenSnapshot]? // Per-app opens with limits & tokens

    var totalPickups: Int { totalBreakthroughs }

    /// Estimated total minutes spent on intention apps this day
    var intentionTimeMinutes: Int {
        guard let snapshots = appOpenSnapshots else { return 0 }
        return snapshots.values.reduce(0) { $0 + $1.opens * $1.sessionMinutes }
    }
}

class WeeklyHistoryManager {
    static let shared = WeeklyHistoryManager()
    private let key = "weeklyDailySnapshots"

    private init() {}

    func saveToday(score: Int, breakthroughsByApp: [String: Int], total: Int, appOpenSnapshots: [String: AppOpenSnapshot]? = nil) {
        var snapshots = loadAll()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Remove existing entry for today if any
        snapshots.removeAll { calendar.isDate($0.date, inSameDayAs: today) }

        let snapshot = DailySnapshot(
            date: today,
            disciplineScore: score,
            breakthroughsByApp: breakthroughsByApp,
            totalBreakthroughs: total,
            appOpenSnapshots: appOpenSnapshots
        )
        snapshots.append(snapshot)

        // Keep only last 30 days
        let cutoff = calendar.date(byAdding: .day, value: -30, to: today)!
        snapshots = snapshots.filter { $0.date >= cutoff }

        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadAll() -> [DailySnapshot] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DailySnapshot].self, from: data) else {
            return []
        }
        return decoded
    }

    func snapshotsForWeek(containing date: Date) -> [DailySnapshot?] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1=Sun
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: date))!

        let allSnapshots = loadAll()
        var week: [DailySnapshot?] = Array(repeating: nil, count: 7)

        for i in 0..<7 {
            let day = calendar.date(byAdding: .day, value: i, to: startOfWeek)!
            week[i] = allSnapshots.first { calendar.isDate($0.date, inSameDayAs: day) }
        }

        return week
    }
}

// MARK: - Screen Time View (Discipline Report)

struct ScreenTimeView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedWeekOffset: Int = 0
    @State private var selectedDayIndex: Int = -1 // -1 = whole week

    private let calendar = Calendar.current
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var referenceDate: Date {
        calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: Date()) ?? Date()
    }

    private var weekSnapshots: [DailySnapshot?] {
        WeeklyHistoryManager.shared.snapshotsForWeek(containing: referenceDate)
    }

    private var weekLabel: String {
        if selectedWeekOffset == 0 { return "This Week" }
        if selectedWeekOffset == -1 { return "Last Week" }
        let startOfWeek = weekStartDate
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: startOfWeek)
    }

    private var weekStartDate: Date {
        let weekday = calendar.component(.weekday, from: referenceDate)
        return calendar.date(byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: referenceDate))!
    }

    private var todayDayIndex: Int {
        let weekday = calendar.component(.weekday, from: Date())
        return weekday - 1 // 0=Sun
    }

    // MARK: - Summary Computed Properties

    private var summaryAvgScore: Int {
        let scores = weekSnapshots.compactMap { $0?.disciplineScore }
        guard !scores.isEmpty else { return 100 }
        return scores.reduce(0, +) / scores.count
    }

    private var summaryTotalPickups: Int {
        weekSnapshots.compactMap { $0?.totalPickups }.reduce(0, +)
    }

    private var summaryDailyAvgPickups: Int {
        let counts = weekSnapshots.compactMap { $0?.totalPickups }
        guard !counts.isEmpty else { return 0 }
        return counts.reduce(0, +) / counts.count
    }

    private var summaryPeakDay: (day: String, pickups: Int) {
        var maxIdx = 0
        var maxVal = 0
        for (i, snapshot) in weekSnapshots.enumerated() {
            let val = snapshot?.totalPickups ?? 0
            if val > maxVal {
                maxVal = val
                maxIdx = i
            }
        }
        return (dayLabels[maxIdx], maxVal)
    }

    private var summaryNevermindCount: Int {
        appState.disciplineScore.nevermindCount
    }

    // MARK: - Display Name Helpers

    /// Reverse the storeKeyMapping (displayName->tokenKey) to get tokenKey->displayName
    private var tokenToDisplayName: [String: String] {
        let mapping = SharedDataManager.shared.loadStoreKeyMapping()
        var reverse: [String: String] = [:]
        for (displayName, tokenKey) in mapping {
            reverse[tokenKey] = displayName
        }
        return reverse
    }

    /// Translate a raw app key to a display name. Token keys like "app_123..." become "Instagram" etc.
    private func displayName(for appKey: String) -> String {
        if appKey.hasPrefix("app_") {
            return tokenToDisplayName[appKey] ?? appKey
        }
        return appKey
    }

    // MARK: - App Intention Time Per Day (minutes)

    /// Estimated total minutes spent on intention apps per day for the week
    private var intentionTimePerDay: [Int] {
        weekSnapshots.map { $0?.intentionTimeMinutes ?? 0 }
    }

    // MARK: - Opens Per App Data

    /// Build app open snapshots from current intentions for saving to history
    private var currentAppOpenSnapshots: [String: AppOpenSnapshot] {
        let intentions = appState.onboardingData.appIntention.perAppIntentions
        let breakthroughs = appState.appUsageStats.breakthroughsByApp

        var snapshots: [String: AppOpenSnapshot] = [:]
        for (key, intention) in intentions {
            // Use display name if available, otherwise keep the key as-is
            let name = displayName(for: key)
            let opens = breakthroughs[key] ?? breakthroughs[name] ?? 0
            snapshots[name] = AppOpenSnapshot(
                opens: opens,
                limit: intention.timesPerDay,
                sessionMinutes: intention.minutesPerSession,
                tokenData: intention.appTokenData
            )
        }
        return snapshots
    }

    /// Today's live opens for each intention app
    private var todayOpensPerIntentionApp: [AppOpenItem] {
        let intentions = appState.onboardingData.appIntention.perAppIntentions
        let breakthroughs = appState.appUsageStats.breakthroughsByApp

        var result: [AppOpenItem] = []
        for (key, intention) in intentions {
            // Use display name if available, otherwise keep the key as-is
            let name = displayName(for: key)
            let opens = breakthroughs[key] ?? breakthroughs[name] ?? 0
            result.append(AppOpenItem(
                id: key, name: name, opens: opens,
                limit: intention.timesPerDay,
                sessionMinutes: intention.minutesPerSession,
                tokenData: intention.appTokenData
            ))
        }
        return result.sorted { $0.opens > $1.opens }
    }

    /// Opens per app for the selected day (historical) or today (live)
    private var opensPerAppForDisplay: [AppOpenItem] {
        if selectedDayIndex >= 0 {
            guard let snapshot = weekSnapshots[selectedDayIndex],
                  let appSnapshots = snapshot.appOpenSnapshots else {
                return []
            }
            return appSnapshots
                .map { AppOpenItem(
                    id: $0.key, name: $0.key, opens: $0.value.opens,
                    limit: $0.value.limit,
                    sessionMinutes: $0.value.sessionMinutes,
                    tokenData: $0.value.tokenData
                )}
                .sorted { $0.opens > $1.opens }
        } else {
            return todayOpensPerIntentionApp
        }
    }

    // MARK: - Score Color

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100: return Color(hex: "34C759")
        case 75..<90: return Color(hex: "5AC8FA")
        case 60..<75: return Color(hex: "FFCC00")
        case 40..<60: return Color(hex: "FF9500")
        default: return Color(hex: "FF3B30")
        }
    }

    private func scoreBgColor(for score: Int) -> Color {
        switch score {
        case 90...100: return Color(hex: "E8F9ED")
        case 75..<90: return Color(hex: "E5F5FC")
        case 60..<75: return Color(hex: "FFF8E0")
        case 40..<60: return Color(hex: "FFF0E0")
        default: return Color(hex: "FFE8E6")
        }
    }

    // MARK: - Time Formatting

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: - Header
                    HStack {
                        Button(action: { selectedWeekOffset -= 1 }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Text("Discipline Report")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text(weekLabel)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "999999"))
                        }

                        Spacer()

                        Button(action: {
                            if selectedWeekOffset < 0 { selectedWeekOffset += 1 }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(selectedWeekOffset < 0 ? Color(hex: "1A1A1A") : Color(hex: "E0E0E0"))
                        }
                        .disabled(selectedWeekOffset >= 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                    // MARK: - Day Picker
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            let snapshot = weekSnapshots[index]
                            let score = snapshot?.disciplineScore ?? 100
                            let isToday = selectedWeekOffset == 0 && index == todayDayIndex
                            let isFuture = selectedWeekOffset == 0 && index > todayDayIndex
                            let hasData = snapshot != nil

                            let dayDate = calendar.date(byAdding: .day, value: index, to: weekStartDate)!
                            let dayNum = calendar.component(.day, from: dayDate)

                            Button(action: {
                                if !isFuture {
                                    selectedDayIndex = selectedDayIndex == index ? -1 : index
                                }
                            }) {
                                VStack(spacing: 6) {
                                    Text(dayLabels[index])
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(isFuture ? Color(hex: "CCCCCC") : Color(hex: "999999"))

                                    ZStack {
                                        Circle()
                                            .fill(isFuture ? Color(hex: "F5F5F5") : (hasData ? scoreBgColor(for: score) : Color(hex: "F5F5F5")))
                                            .frame(width: 38, height: 38)

                                        Text("\(score)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(isFuture ? Color(hex: "CCCCCC") : (hasData ? scoreColor(for: score) : Color(hex: "CCCCCC")))
                                    }

                                    Text("\(dayNum)")
                                        .font(.system(size: 12, weight: isToday ? .bold : .medium))
                                        .foregroundColor(isToday ? Color(hex: "1A1A1A") : (isFuture ? Color(hex: "CCCCCC") : Color(hex: "666666")))
                                }
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedDayIndex == index ? Color.white : Color.clear)
                                        .shadow(color: selectedDayIndex == index ? Color.black.opacity(0.06) : .clear, radius: 4, y: 2)
                                )
                            }
                            .buttonStyle(HapticButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // MARK: - Summary Section
                    Text("Summary")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            summaryCell(label: "AVG SCORE", value: "\(summaryAvgScore)", subtitle: "/100")
                            Rectangle().fill(Color(hex: "F0F0F0")).frame(width: 1)
                            summaryCell(label: "TOTAL OPENS", value: "\(summaryTotalPickups)", subtitle: nil)
                        }
                        .frame(height: 90)

                        Rectangle().fill(Color(hex: "F0F0F0")).frame(height: 1)

                        HStack(spacing: 0) {
                            summaryCell(label: "PEAK DAY", value: summaryPeakDay.day, subtitle: "\(summaryPeakDay.pickups) opens")
                            Rectangle().fill(Color(hex: "F0F0F0")).frame(width: 1)
                            summaryCell(label: "DAILY AVG", value: "\(summaryDailyAvgPickups)", subtitle: "opens/day")
                        }
                        .frame(height: 90)
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // MARK: - Opens Per Day Chart
                    Text("Opens Per Day")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    barChart(
                        values: weekSnapshots.map { $0?.totalPickups ?? 0 },
                        barColor: Color(hex: "5AC8FA"),
                        isFutureCheck: true,
                        labelFormatter: nil
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // MARK: - App Intention Time Chart
                    Text("App Intention Time")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    barChart(
                        values: intentionTimePerDay,
                        barColor: Color(hex: "5AC8FA"),
                        isFutureCheck: true,
                        labelFormatter: formatMinutes
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // MARK: - Mood Overview Chart
                    Text("Mood Overview")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    moodBarChart
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                    // MARK: - App Intention Opens (always visible)
                    Text(selectedDayIndex >= 0 ? "App Intention Opens" : "Today's App Intention Opens")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    if opensPerAppForDisplay.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "app.badge")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "CCCCCC"))

                            Text("No app intention data")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))

                            Text("Open your blocked apps to see activity here")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "CCCCCC"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(opensPerAppForDisplay) { item in
                                if item.id != opensPerAppForDisplay.first?.id {
                                    Rectangle().fill(Color(hex: "F5F5F5")).frame(height: 1)
                                        .padding(.horizontal, 16)
                                }

                                HStack(spacing: 12) {
                                    // Real app icon
                                    appOpenIcon(tokenData: item.tokenData, fallbackName: item.name, size: 40, cornerRadius: 10)

                                    VStack(alignment: .leading, spacing: 3) {
                                        // Real app name
                                        appOpenName(tokenData: item.tokenData, fallbackName: item.name)

                                        HStack(spacing: 12) {
                                            // Opens count
                                            HStack(spacing: 3) {
                                                Image(systemName: "arrow.up.right.square")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color(hex: "999999"))
                                                Text("\(item.opens)/\(item.limit) opens")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color(hex: "999999"))
                                            }

                                            // Time estimate
                                            HStack(spacing: 3) {
                                                Image(systemName: "clock")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color(hex: "999999"))
                                                Text(formatMinutes(item.opens * item.sessionMinutes))
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color(hex: "999999"))
                                            }
                                        }
                                    }

                                    Spacer()

                                    // Progress circle
                                    ZStack {
                                        Circle()
                                            .stroke(Color(hex: "F0F0F0"), lineWidth: 4)
                                            .frame(width: 44, height: 44)

                                        Circle()
                                            .trim(from: 0, to: item.limit > 0 ? min(CGFloat(item.opens) / CGFloat(item.limit), 1.0) : 0)
                                            .stroke(
                                                item.opens >= item.limit ? Color(hex: "FF3B30") : Color(hex: "34C759"),
                                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                            )
                                            .frame(width: 44, height: 44)
                                            .rotationEffect(.degrees(-90))

                                        Text("\(item.opens)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(item.opens >= item.limit ? Color(hex: "FF3B30") : Color(hex: "1A1A1A"))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                    }

                    Spacer().frame(height: 120)
                }
            }
        }
        .onAppear {
            // Save today's snapshot with per-app open data for historical records
            WeeklyHistoryManager.shared.saveToday(
                score: appState.disciplineScore.score,
                breakthroughsByApp: appState.appUsageStats.breakthroughsByApp,
                total: appState.appUsageStats.breakthroughsToday,
                appOpenSnapshots: currentAppOpenSnapshots
            )
        }
    }

    // MARK: - Mood Chart

    private var moodAverages: [Double?] {
        SharedDataManager.shared.moodAveragesForWeek(containing: referenceDate)
    }

    private func moodColor(for score: Double) -> Color {
        switch score {
        case 4.5...5: return Color(hex: "10B981") // Great - green
        case 3.5..<4.5: return Color(hex: "3B82F6") // Good - blue
        case 2.5..<3.5: return Color(hex: "F59E0B") // Okay - amber
        case 1.5..<2.5: return Color(hex: "EF4444") // Not great - red
        default: return Color(hex: "DC2626") // Struggling - dark red
        }
    }

    private func moodLabel(for score: Double) -> String {
        switch score {
        case 4.5...5: return "😊"
        case 3.5..<4.5: return "🙂"
        case 2.5..<3.5: return "😐"
        case 1.5..<2.5: return "😔"
        default: return "😞"
        }
    }

    @ViewBuilder
    private var moodBarChart: some View {
        let averages = moodAverages
        let hasAnyData = averages.contains(where: { $0 != nil })

        if hasAnyData {
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(0..<7, id: \.self) { index in
                        let isFuture = selectedWeekOffset == 0 && index > todayDayIndex
                        let avg = averages[index]

                        VStack(spacing: 4) {
                            if !isFuture, let score = avg {
                                Text(moodLabel(for: score))
                                    .font(.system(size: 14))
                            }

                            if isFuture {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "F0F0F0"))
                                    .frame(height: 0)
                                    .frame(maxWidth: .infinity)
                            } else if let score = avg {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(moodColor(for: score))
                                    .frame(height: CGFloat(score) / 5.0 * 120)
                                    .frame(maxWidth: .infinity)
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "F0F0F0"))
                                    .frame(height: 0)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .frame(height: 150, alignment: .bottom)
                .padding(.bottom, 8)

                // Y-axis labels on the left side
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { index in
                        let isFuture = selectedWeekOffset == 0 && index > todayDayIndex
                        Text(dayLabels[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isFuture ? Color(hex: "CCCCCC") : Color(hex: "999999"))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "CCCCCC"))

                Text("No mood data yet")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "999999"))

                Text("Complete app interventions to track your mood")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "CCCCCC"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
            )
        }
    }

    // MARK: - Summary Cell

    @ViewBuilder
    private func summaryCell(label: String, value: String, subtitle: String?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "999999"))
                .tracking(0.5)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "999999"))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bar Chart

    @ViewBuilder
    private func barChart(values: [Int], barColor: Color, isFutureCheck: Bool, labelFormatter: ((Int) -> String)?) -> some View {
        let maxVal = max(values.max() ?? 1, 1)

        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<7, id: \.self) { index in
                    let value = values[index]
                    let isFuture = isFutureCheck && selectedWeekOffset == 0 && index > todayDayIndex
                    let barHeight: CGFloat = isFuture ? 0 : max(CGFloat(value) / CGFloat(maxVal) * 120, value > 0 ? 20 : 0)

                    VStack(spacing: 4) {
                        if !isFuture && value > 0 {
                            Text(labelFormatter?(value) ?? "\(value)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }

                        RoundedRectangle(cornerRadius: 6)
                            .fill(isFuture ? Color(hex: "F0F0F0") : (value > 0 ? barColor : Color(hex: "F0F0F0")))
                            .frame(height: barHeight)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 150, alignment: .bottom)
            .padding(.bottom, 8)

            HStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { index in
                    let isFuture = isFutureCheck && selectedWeekOffset == 0 && index > todayDayIndex
                    Text(dayLabels[index])
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isFuture ? Color(hex: "CCCCCC") : Color(hex: "999999"))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
        )
    }

    // MARK: - App Icon/Name Helpers

    /// Finds token data for an app by looking up intentions
    private func findTokenData(for appName: String) -> Data? {
        let intentions = appState.onboardingData.appIntention.perAppIntentions
        if let intention = intentions[appName] {
            return intention.appTokenData
        }
        let mapping = SharedDataManager.shared.loadStoreKeyMapping()
        if let tokenKey = mapping[appName], let intention = intentions[tokenKey] {
            return intention.appTokenData
        }
        return nil
    }

    /// Renders a real app icon from explicit token data, or a colored fallback
    @ViewBuilder
    private func appOpenIcon(tokenData: Data?, fallbackName: String, size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let data = tokenData,
           let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
            Label(token)
                .labelStyle(.iconOnly)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(appColor(for: fallbackName))
                .frame(width: size, height: size)
                .overlay(
                    Text(String(fallbackName.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    /// Renders an app name from token data, or falls back to the string name
    @ViewBuilder
    private func appOpenName(tokenData: Data?, fallbackName: String) -> some View {
        if let data = tokenData,
           let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
            Label(token)
                .labelStyle(.titleOnly)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "1A1A1A"))
        } else {
            Text(fallbackName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "1A1A1A"))
        }
    }

    // MARK: - App Color (deterministic)

    private func appColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(hex: "1A1A1A"),
            Color(hex: "FF6B35"),
            Color(hex: "5AC8FA"),
            Color(hex: "34C759"),
            Color(hex: "FF3B30"),
            Color(hex: "AF52DE"),
            Color(hex: "FFCC00"),
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}
