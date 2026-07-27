import SwiftUI

/// Celebratory overlay shown on the home screen after a real alarm is completed and the day's
/// streak is counted. A card over the slightly-blurred home screen showing the current week
/// (Sunday-first): 🔥 on completed days (today's 🔥 animates in), a faint grey marker on missed
/// days, empty for future days — with the streak count underneath. Tap anywhere to continue.
@available(iOS 16.0, *)
struct StreakCelebrationView: View {
    let completedDays: Set<String>   // "yyyy-MM-dd"
    let streak: Int
    let onContinue: () -> Void

    @State private var cardScale: CGFloat = 0.85
    @State private var cardOpacity: Double = 0
    @State private var todayFireScale: CGFloat = 0

    private let cal = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private enum SlotState { case completed, today, missed, future }

    /// The 7 days of the current week, Sunday-first (matches StreakCalendarView's convention).
    private var weekDays: [Date] {
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)   // 1 = Sunday
        guard let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: today) else {
            return []
        }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func state(for day: Date) -> SlotState {
        let today = cal.startOfDay(for: Date())
        if cal.isDate(day, inSameDayAs: today) { return .today }
        if completedDays.contains(Self.keyFormatter.string(from: day)) { return .completed }
        if day < today { return .missed }
        return .future
    }

    var body: some View {
        ZStack {
            // Slightly blurred, dimmed backdrop over the home screen. Tap anywhere to continue.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.12).ignoresSafeArea())
                .contentShape(Rectangle())
                .onTapGesture { onContinue() }

            VStack(spacing: 20) {
                Text("Streak secured!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                // Week strip.
                HStack(spacing: 10) {
                    ForEach(Array(weekDays.enumerated()), id: \.offset) { idx, day in
                        VStack(spacing: 8) {
                            Text(weekdaySymbols[idx])
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "999999"))
                            slot(for: state(for: day))
                        }
                    }
                }

                // Streak count underneath the week.
                Text("\(streak) day streak")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text("Tap to continue")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "BBBBBB"))
                    .padding(.top, 4)
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 32)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            // Today's 🔥 pops in with a bounce, slightly after the card lands.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.25)) {
                todayFireScale = 1.0
            }
        }
    }

    @ViewBuilder
    private func slot(for s: SlotState) -> some View {
        ZStack {
            Circle()
                .fill(circleFill(s))
                .frame(width: 36, height: 36)

            switch s {
            case .completed:
                Text("🔥").font(.system(size: 20))
            case .today:
                Text("🔥").font(.system(size: 22)).scaleEffect(todayFireScale)
            case .missed:
                Circle().fill(Color(hex: "D8D8D8")).frame(width: 8, height: 8)   // faint grey
            case .future:
                EmptyView()
            }
        }
    }

    private func circleFill(_ s: SlotState) -> Color {
        switch s {
        case .completed: return Color(hex: "FFF3E0")
        case .today:     return Color(hex: "FFE0B2")
        case .missed:    return Color(hex: "F2F2F2")
        case .future:    return Color(hex: "F7F7F7")
        }
    }
}
