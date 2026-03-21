import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct AffirmationEntry: TimelineEntry {
    let date: Date
    let affirmation: String
    let score: Int
    let theme: WidgetTheme
}

// MARK: - Timeline Provider

struct AffirmationProvider: TimelineProvider {
    func placeholder(in context: Context) -> AffirmationEntry {
        AffirmationEntry(
            date: Date(),
            affirmation: "You are worthy of all the good things life has to offer.",
            score: 85,
            theme: WidgetDataProvider.resolveTheme(id: "starry-mountains")
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AffirmationEntry) -> Void) {
        let now = Date()
        let affirmation = WidgetDataProvider.getAffirmation(for: now)
        let score = WidgetDataProvider.loadDisciplineScore()
        let themeId = WidgetDataProvider.loadSelectedThemeId()
        let theme = WidgetDataProvider.resolveTheme(id: themeId)
        completion(AffirmationEntry(date: now, affirmation: affirmation, score: score, theme: theme))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AffirmationEntry>) -> Void) {
        var entries: [AffirmationEntry] = []
        let now = Date()
        let calendar = Calendar.current
        let themeId = WidgetDataProvider.loadSelectedThemeId()
        let theme = WidgetDataProvider.resolveTheme(id: themeId)

        // Create entries for the next 2 hours (every 15 minutes = 8 entries)
        for i in 0..<8 {
            let entryDate = calendar.date(byAdding: .minute, value: i * 15, to: now)!
            let affirmation = WidgetDataProvider.getAffirmation(for: entryDate)
            let score = WidgetDataProvider.loadDisciplineScore()
            entries.append(AffirmationEntry(date: entryDate, affirmation: affirmation, score: score, theme: theme))
        }

        let nextUpdate = calendar.date(byAdding: .hour, value: 2, to: now)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Theme Background View

struct ThemeBackgroundView: View {
    let theme: WidgetTheme

    var body: some View {
        if theme.type == "image" {
            Image(theme.background)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if theme.type == "gradient", let end = theme.gradientEnd {
            LinearGradient(
                colors: [Color(hex: theme.background), Color(hex: end)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(hex: theme.background)
        }
    }
}

// MARK: - Medium Widget View (Score Ring + Affirmation)

struct AffirmationMediumView: View {
    let entry: AffirmationEntry

    private var textColor: Color { Color(hex: entry.theme.textColor) }
    private var accentColor: Color { Color(hex: entry.theme.accentColor) }

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: entry.theme)
                .clipped()

            // Dark overlay for readability
            Color.black.opacity(0.2)

            HStack(spacing: 16) {
                // Score ring on the left
                ZStack {
                    Circle()
                        .stroke(textColor.opacity(0.15), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: Double(entry.score) / 100.0)
                        .stroke(
                            scoreColor(entry.score),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(entry.score)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)

                        Text("score")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(textColor.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                }
                .frame(width: 80, height: 80)
                .padding(.leading, 4)

                // Divider line
                Rectangle()
                    .fill(textColor.opacity(0.2))
                    .frame(width: 1)
                    .padding(.vertical, 16)

                // Affirmation on the right
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.affirmation.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(textColor)
                        .lineSpacing(3)
                        .tracking(0.3)
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundColor(textColor.opacity(0.5))
                        Text("BeYou")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(textColor.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return Color(hex: "34D399") }
        if score >= 60 { return Color(hex: "FBBF24") }
        return Color(hex: "F87171")
    }
}

// MARK: - Large Widget View (Full Affirmation)

struct AffirmationLargeView: View {
    let entry: AffirmationEntry

    private var textColor: Color { Color(hex: entry.theme.textColor) }

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: entry.theme)
                .clipped()

            // Dark overlay for readability
            Color.black.opacity(0.2)

            VStack(spacing: 0) {
                Spacer()

                // Decorative quote mark
                Text("\u{201C}")
                    .font(.system(size: 56, weight: .bold, design: .serif))
                    .foregroundColor(textColor.opacity(0.2))
                    .offset(y: 10)

                // Affirmation text
                Text(entry.affirmation.uppercased())
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .tracking(0.5)
                    .padding(.horizontal, 24)
                    .minimumScaleFactor(0.7)

                Spacer()

                // Bottom bar: score ring + branding
                HStack {
                    // Mini score ring
                    ZStack {
                        Circle()
                            .stroke(textColor.opacity(0.1), lineWidth: 3)

                        Circle()
                            .trim(from: 0, to: Double(entry.score) / 100.0)
                            .stroke(
                                scoreColor(entry.score),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Text("\(entry.score)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                    }
                    .frame(width: 32, height: 32)

                    Text("Discipline")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textColor.opacity(0.5))

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("BeYou")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(textColor.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return Color(hex: "34D399") }
        if score >= 60 { return Color(hex: "FBBF24") }
        return Color(hex: "F87171")
    }
}

// MARK: - Widget Definition

struct AffirmationWidget: Widget {
    let kind = "AffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AffirmationProvider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                WidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Affirmation")
        .description("Stay motivated with personalized affirmations.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Adaptive Entry View

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AffirmationEntry

    var body: some View {
        switch family {
        case .systemMedium:
            AffirmationMediumView(entry: entry)
        case .systemLarge:
            AffirmationLargeView(entry: entry)
        default:
            AffirmationMediumView(entry: entry)
        }
    }
}
