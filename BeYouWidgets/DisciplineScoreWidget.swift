import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct DisciplineScoreEntry: TimelineEntry {
    let date: Date
    let score: Int
}

// MARK: - Timeline Provider

struct DisciplineScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> DisciplineScoreEntry {
        DisciplineScoreEntry(date: Date(), score: 85)
    }

    func getSnapshot(in context: Context, completion: @escaping (DisciplineScoreEntry) -> Void) {
        let score = WidgetDataProvider.loadDisciplineScore()
        completion(DisciplineScoreEntry(date: Date(), score: score))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DisciplineScoreEntry>) -> Void) {
        let score = WidgetDataProvider.loadDisciplineScore()
        let entry = DisciplineScoreEntry(date: Date(), score: score)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Score Ring View

struct ScoreRingView: View {
    let score: Int
    let size: CGFloat

    private var progress: Double {
        Double(score) / 100.0
    }

    private var ringColor: Color {
        if score >= 80 {
            return Color(hex: "34D399") // Green
        } else if score >= 60 {
            return Color(hex: "FBBF24") // Yellow
        } else {
            return Color(hex: "F87171") // Red
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: size * 0.1)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: score)

            // Score text
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text("score")
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundColor(Color(hex: "999999"))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Small Widget View

struct DisciplineScoreSmallView: View {
    let entry: DisciplineScoreEntry

    private var ringColor: Color {
        if entry.score >= 80 { return Color(hex: "34D399") }
        if entry.score >= 60 { return Color(hex: "FBBF24") }
        return Color(hex: "F87171")
    }

    var body: some View {
        ZStack {
            // Dark background
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A1A1A"), Color(hex: "2A2A2A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("Discipline")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.8)

                // Dark-themed score ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 9)

                    Circle()
                        .trim(from: 0, to: Double(entry.score) / 100.0)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(entry.score)")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("score")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                }
                .frame(width: 90, height: 90)
            }
        }
    }
}

// MARK: - Widget Definition

struct DisciplineScoreWidget: Widget {
    let kind = "DisciplineScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DisciplineScoreProvider()) { entry in
            if #available(iOS 17.0, *) {
                DisciplineScoreSmallView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [Color(hex: "1A1A1A"), Color(hex: "2A2A2A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                DisciplineScoreSmallView(entry: entry)
                    .padding()
                    .background(Color(hex: "1A1A1A"))
            }
        }
        .configurationDisplayName("Discipline Score")
        .description("Track your daily discipline score.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
