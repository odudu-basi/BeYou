import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct AffirmationEntry: TimelineEntry {
    let date: Date
    let affirmation: String
    let theme: WidgetTheme
}

// MARK: - Timeline Provider

struct AffirmationProvider: TimelineProvider {
    func placeholder(in context: Context) -> AffirmationEntry {
        AffirmationEntry(
            date: Date(),
            affirmation: "You are worthy of all the good things life has to offer.",
            theme: WidgetDataProvider.resolveTheme(id: "starry-mountains")
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AffirmationEntry) -> Void) {
        let now = Date()
        let affirmation = WidgetDataProvider.getAffirmation(for: now)
        let themeId = WidgetDataProvider.loadSelectedThemeId()
        let theme = WidgetDataProvider.resolveTheme(id: themeId)
        completion(AffirmationEntry(date: now, affirmation: affirmation, theme: theme))
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
            entries.append(AffirmationEntry(date: entryDate, affirmation: affirmation, theme: theme))
        }

        let nextUpdate = calendar.date(byAdding: .hour, value: 2, to: now)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget View (Affirmation Only)

struct AffirmationSmallView: View {
    let entry: AffirmationEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A1A1A"), Color(hex: "2A2A2A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 0) {
                Spacer()

                Text(entry.affirmation.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .tracking(0.3)
                    .lineLimit(5)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 14)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("BeYou")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.white.opacity(0.4))
                .padding(.bottom, 12)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Medium Widget View (Affirmation)

struct AffirmationMediumView: View {
    let entry: AffirmationEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A1A1A"), Color(hex: "2A2A2A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text(entry.affirmation.uppercased())
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .tracking(0.3)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.4))
                    Text("BeYou")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Large Widget View (Full Affirmation)

struct AffirmationLargeView: View {
    let entry: AffirmationEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A1A1A"), Color(hex: "2A2A2A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 0) {
                Spacer()

                // Decorative quote mark
                Text("\u{201C}")
                    .font(.system(size: 56, weight: .bold, design: .serif))
                    .foregroundColor(Color.white.opacity(0.15))
                    .offset(y: 10)

                // Affirmation text
                Text(entry.affirmation.uppercased())
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .tracking(0.5)
                    .padding(.horizontal, 24)
                    .minimumScaleFactor(0.7)

                Spacer()

                // Bottom branding
                HStack {
                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("BeYou")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Widget Definition

struct AffirmationWidget: Widget {
    let kind = "AffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AffirmationProvider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [Color(hex: "1A1A1A"), Color(hex: "2A2A2A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                WidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Affirmation")
        .description("Stay motivated with personalized affirmations.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Adaptive Entry View

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AffirmationEntry

    var body: some View {
        switch family {
        case .systemSmall:
            AffirmationSmallView(entry: entry)
        case .systemMedium:
            AffirmationMediumView(entry: entry)
        case .systemLarge:
            AffirmationLargeView(entry: entry)
        default:
            AffirmationSmallView(entry: entry)
        }
    }
}
