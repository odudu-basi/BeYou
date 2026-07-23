import SwiftUI

/// The "Today's Affirmation" card + its tap-to-open-detail flow, extracted so both the Home tab and
/// the post-alarm screen show the EXACT same card and open the same full affirmation experience
/// (`TodayAffirmationDetailView`). Reads the same global state the Home card uses.
@available(iOS 16.0, *)
struct TodayAffirmationCard: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("selectedMotivationTheme") private var affirmationThemeId: String = "ocean-gradient"
    @AppStorage("selectedAffirmationCategories") private var selectedCategoriesData: Data = Data()
    @State private var showDetail = false

    private var theme: MotivationTheme {
        defaultThemes.first(where: { $0.id == affirmationThemeId }) ?? defaultThemes[0]
    }

    private var cardCategories: [String] {
        let raw = (try? JSONDecoder().decode(Set<String>.self, from: selectedCategoriesData)) ?? []
        let cleaned = raw.filter { !$0.hasPrefix("__religion_") && $0 != "Favourites" }
        return cleaned.isEmpty ? ["Self-love", "Confidence"] : Array(cleaned)
    }

    private var todaysAffirmation: String {
        let data = appState.onboardingData
        let cats = cardCategories
        let catSet = Set(cats)
        let matched = AffirmationService.shared.getAllMatchedAffirmations(
            categories: cats,
            goals: data.goals,
            belief: data.beliefs.first ?? "general",
            name: data.name ?? ""
        )
        let inCategory = matched.filter { !Set($0.categories).isDisjoint(with: catSet) }
        let pool = (inCategory.isEmpty ? matched : inCategory).map { $0.text }
        guard !pool.isEmpty else { return "You are exactly where you need to be." }
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let daySeed = (comps.year ?? 2026) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
        return pool[daySeed % pool.count]
    }

    var body: some View {
        card
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                Haptics.tap()
                AnalyticsManager.shared.trackAffirmationDetailOpened(categories: cardCategories)
                showDetail = true
            }
            .fullScreenCover(isPresented: $showDetail) {
                TodayAffirmationDetailView()
                    .environmentObject(appState)   // covers don't reliably inherit env objects here
            }
    }

    private var card: some View {
        Text(todaysAffirmation.uppercased())
            .font(.system(size: 22, weight: .heavy))
            .foregroundColor(Color(hex: theme.textColor))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .lineLimit(6)
            .minimumScaleFactor(0.6)
            .tracking(0.5)
            .shadow(color: Color.black.opacity(theme.type == "solid" ? 0 : 0.5), radius: 4, x: 0, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(20)
            .frame(height: 240)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var cardBackground: some View {
        ZStack {
            GeometryReader { geo in
                Group {
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
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }

            if theme.type != "solid" {
                LinearGradient(
                    colors: [Color.black.opacity(0.1), Color.black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}
