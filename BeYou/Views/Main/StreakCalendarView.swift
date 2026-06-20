import SwiftUI

/// Month-by-month history of which days the user completed an alarm (success) and
/// which fully-elapsed days they missed. Opened from the Day Streak card on Insights.
@available(iOS 16.0, *)
struct StreakCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    let completedDays: Set<String> // "yyyy-MM-dd"

    private let cal = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private enum DayStatus { case success, missed, neutral }

    /// First day the user ever completed an alarm — tracking starts here.
    private var earliest: Date? {
        completedDays
            .compactMap { Self.keyFormatter.date(from: $0) }
            .min()
            .map { cal.startOfDay(for: $0) }
    }

    /// Months from the first completion to the current month, most recent first.
    private var months: [Date] {
        guard let earliest else { return [] }
        let today = cal.startOfDay(for: Date())
        let currentMonth = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        var month = cal.date(from: cal.dateComponents([.year, .month], from: earliest))!

        var result: [Date] = []
        while month <= currentMonth {
            result.append(month)
            guard let next = cal.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result.reversed()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                if months.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 24) {
                        legend
                        ForEach(months, id: \.self) { month in
                            monthCard(month)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .background(Color(hex: "F8F8F8").ignoresSafeArea())
            .navigationTitle("Streak History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
            }
        }
    }

    // MARK: - Pieces

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "CCCCCC"))
            Text("No streak history yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: "999999"))
            Text("Complete an alarm to start tracking your days")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "BBBBBB"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .padding(.horizontal, 40)
    }

    private var legend: some View {
        HStack(spacing: 24) {
            legendItem(color: Color(hex: "34C759"), label: "Completed")
            legendItem(color: Color(hex: "EF4444").opacity(0.15), label: "Missed", dotBordered: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String, dotBordered: Bool = false) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "666666"))
        }
    }

    private func monthCard(_ month: Date) -> some View {
        let cells = daysGrid(for: month)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return VStack(alignment: .leading, spacing: 12) {
            Text(Self.monthFormatter.string(from: month))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))

            HStack(spacing: 0) {
                ForEach(weekdaySymbols.indices, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "999999"))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cells.indices, id: \.self) { idx in
                    if let date = cells[idx] {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func dayCell(_ date: Date) -> some View {
        let status = status(for: date)
        let day = cal.component(.day, from: date)

        return ZStack {
            Circle()
                .fill(fillColor(status))
                .frame(width: 36, height: 36)

            if status == .success {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(day)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor(status))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic

    /// Optional dates aligned to Sunday-first weekday columns (nil = leading blank).
    private func daysGrid(for month: Date) -> [Date?] {
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        guard let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) // 1 = Sunday

        var cells: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for offset in 0..<range.count {
            cells.append(cal.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        return cells
    }

    private func status(for date: Date) -> DayStatus {
        let day = cal.startOfDay(for: date)
        let key = Self.keyFormatter.string(from: day)
        if completedDays.contains(key) { return .success }

        let today = cal.startOfDay(for: Date())
        // Missed = a fully-elapsed day on/after tracking started with no completion.
        if let earliest, day >= earliest, day < today { return .missed }
        return .neutral
    }

    private func fillColor(_ status: DayStatus) -> Color {
        switch status {
        case .success: return Color(hex: "34C759")
        case .missed: return Color(hex: "EF4444").opacity(0.15)
        case .neutral: return Color(hex: "F2F2F2")
        }
    }

    private func textColor(_ status: DayStatus) -> Color {
        switch status {
        case .success: return .white
        case .missed: return Color(hex: "EF4444")
        case .neutral: return Color(hex: "BBBBBB")
        }
    }
}
