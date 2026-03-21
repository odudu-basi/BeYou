import SwiftUI
import UIKit

// MARK: - Theme Model

struct MotivationTheme: Identifiable {
    let id: String
    let name: String
    let type: String // "solid", "gradient", or "image"
    let background: String // hex color or asset image name
    let gradientEnd: String?
    let textColor: String
    let accentColor: String
}

// MARK: - Theme Section Model

struct ThemeSection: Identifiable {
    let id: String
    let name: String
    let icon: String
    let themes: [MotivationTheme]
}

let natureThemes: [MotivationTheme] = [
    MotivationTheme(id: "deep-forest", name: "Deep Forest", type: "image", background: "theme-deep-forest", gradientEnd: nil, textColor: "FFFFFF", accentColor: "7BB06A"),
    MotivationTheme(id: "alpine-lake", name: "Alpine Lake", type: "image", background: "theme-alpine-lake", gradientEnd: nil, textColor: "FFFFFF", accentColor: "6EC4D8"),
    MotivationTheme(id: "golden-peaks", name: "Golden Peaks", type: "image", background: "theme-golden-peaks", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D4A850"),
    MotivationTheme(id: "misty-summit", name: "Misty Summit", type: "image", background: "theme-misty-summit", gradientEnd: nil, textColor: "FFFFFF", accentColor: "A0B8C8"),
    MotivationTheme(id: "starry-mountains", name: "Starry Mountains", type: "image", background: "theme-starry-mountains", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D4A060"),
    MotivationTheme(id: "arctic-night", name: "Arctic Night", type: "image", background: "theme-arctic-night", gradientEnd: nil, textColor: "FFFFFF", accentColor: "7AAAC0"),
    MotivationTheme(id: "northern-lights", name: "Northern Lights", type: "image", background: "theme-northern-lights", gradientEnd: nil, textColor: "FFFFFF", accentColor: "6CD8A0"),
    MotivationTheme(id: "forest-canopy", name: "Forest Canopy", type: "image", background: "theme-forest-canopy", gradientEnd: nil, textColor: "FFFFFF", accentColor: "90D060"),
    MotivationTheme(id: "gentle-waves", name: "Gentle Waves", type: "image", background: "theme-gentle-waves", gradientEnd: nil, textColor: "FFFFFF", accentColor: "80C0C8"),
    MotivationTheme(id: "enchanted-forest", name: "Enchanted Forest", type: "image", background: "theme-enchanted-forest", gradientEnd: nil, textColor: "FFFFFF", accentColor: "5890D0"),
    MotivationTheme(id: "golden-butterfly", name: "Golden Butterfly", type: "image", background: "theme-golden-butterfly", gradientEnd: nil, textColor: "FFFFFF", accentColor: "C8B040"),
    MotivationTheme(id: "golden-shore", name: "Golden Shore", type: "image", background: "theme-golden-shore", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D4A868"),
    MotivationTheme(id: "violet-sea", name: "Violet Sea", type: "image", background: "theme-violet-sea", gradientEnd: nil, textColor: "FFFFFF", accentColor: "B888D0"),
    MotivationTheme(id: "cloud-valley", name: "Cloud Valley", type: "image", background: "theme-cloud-valley", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D8B888"),
    MotivationTheme(id: "ocean-gradient", name: "Ocean Gradient", type: "image", background: "theme-ocean-gradient", gradientEnd: nil, textColor: "FFFFFF", accentColor: "60B8B0"),
    MotivationTheme(id: "sunset-blaze", name: "Sunset Blaze", type: "image", background: "theme-sunset-blaze", gradientEnd: nil, textColor: "FFFFFF", accentColor: "E08850"),
    MotivationTheme(id: "pink-shores", name: "Pink Shores", type: "image", background: "theme-pink-shores", gradientEnd: nil, textColor: "FFFFFF", accentColor: "D88098"),
]

let solidThemes: [MotivationTheme] = [
    MotivationTheme(id: "desert-sand", name: "Desert Sand", type: "solid", background: "E8E0D4", gradientEnd: nil, textColor: "3D3A33", accentColor: "5C5647"),
    MotivationTheme(id: "midnight", name: "Midnight", type: "solid", background: "1A1A2E", gradientEnd: nil, textColor: "E0E0E0", accentColor: "8888AA"),
    MotivationTheme(id: "ocean-mist", name: "Ocean Mist", type: "solid", background: "D4E8E0", gradientEnd: nil, textColor: "2E3D33", accentColor: "476056"),
    MotivationTheme(id: "lavender-dream", name: "Lavender Dream", type: "solid", background: "E0D4E8", gradientEnd: nil, textColor: "3A2E3D", accentColor: "5C4768"),
    MotivationTheme(id: "warm-blush", name: "Warm Blush", type: "solid", background: "F2D9D5", gradientEnd: nil, textColor: "4A2F2B", accentColor: "8B5E57"),
    MotivationTheme(id: "forest-green", name: "Forest Green", type: "solid", background: "2D4A3E", gradientEnd: nil, textColor: "D4E8DC", accentColor: "8BB89E"),
    MotivationTheme(id: "charcoal", name: "Charcoal", type: "solid", background: "2A2A2A", gradientEnd: nil, textColor: "E8E8E8", accentColor: "888888"),
    MotivationTheme(id: "pure-white", name: "Pure White", type: "solid", background: "FFFFFF", gradientEnd: nil, textColor: "1A1A1A", accentColor: "666666"),
    MotivationTheme(id: "sage", name: "Sage", type: "solid", background: "C5CDB0", gradientEnd: nil, textColor: "2E3325", accentColor: "5C6347"),
]

let gradientThemes: [MotivationTheme] = [
    MotivationTheme(id: "sunrise", name: "Sunrise", type: "gradient", background: "FFB88C", gradientEnd: "DE6262", textColor: "FFFFFF", accentColor: "8B5E3C"),
    MotivationTheme(id: "deep-ocean", name: "Deep Ocean", type: "gradient", background: "1A3A5C", gradientEnd: "0F2744", textColor: "D4E0E8", accentColor: "6B8BA4"),
    MotivationTheme(id: "cotton-candy", name: "Cotton Candy", type: "gradient", background: "E8D4E0", gradientEnd: "D4C4E8", textColor: "3D2E3A", accentColor: "7B5C6E"),
]

let themeSections: [ThemeSection] = [
    ThemeSection(id: "nature", name: "Nature", icon: "leaf.fill", themes: natureThemes),
    ThemeSection(id: "solid", name: "Solid Colors", icon: "circle.fill", themes: solidThemes),
    ThemeSection(id: "gradient", name: "Gradients", icon: "circle.lefthalf.filled", themes: gradientThemes),
]

let defaultThemes: [MotivationTheme] = natureThemes + solidThemes + gradientThemes

// MARK: - Motivation View

struct MotivationView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentIndex: Int = 0
    @State private var showThemePicker = false
    @State private var showCategoryPicker = false
    @State private var dragOffset: CGFloat = 0
    @State private var swipeDirection: SwipeDirection = .up
    @State private var sessionSeed: Int = Int.random(in: 0..<Int.max)
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showHeartAnimation = false

    private enum SwipeDirection {
        case up, down
    }
    @AppStorage("selectedMotivationTheme") private var selectedThemeId: String = "starry-mountains"
    @AppStorage("selectedAffirmationCategories") private var selectedCategoriesData: Data = Data()
    @AppStorage("hasInitializedCategories") private var hasInitializedCategories: Bool = false
    @AppStorage("favoriteAffirmations") private var favoriteAffirmationsData: Data = Data()

    private var favoriteAffirmations: Set<String> {
        (try? JSONDecoder().decode(Set<String>.self, from: favoriteAffirmationsData)) ?? []
    }

    private func saveFavorites(_ favorites: Set<String>) {
        if let data = try? JSONEncoder().encode(favorites) {
            favoriteAffirmationsData = data
        }
    }

    private var isShowingFavorites: Bool {
        selectedCategories.contains("Favourites")
    }

    private var selectedCategories: Set<String> {
        let raw = (try? JSONDecoder().decode(Set<String>.self, from: selectedCategoriesData)) ?? []
        // Filter out internal religion markers
        return raw.filter { !$0.hasPrefix("__religion_") }
    }

    private var isReligionIncluded: Bool {
        let raw = (try? JSONDecoder().decode(Set<String>.self, from: selectedCategoriesData)) ?? []
        if raw.contains("__religion_excluded__") { return false }
        if raw.contains("__religion_included__") { return true }
        // Default: include if user has a religion
        let belief = appState.onboardingData.beliefs.first ?? "general"
        return belief != "general"
    }

    private var affirmations: [String] {
        // If showing favourites, return only saved favorites
        if isShowingFavorites {
            let favs = Array(favoriteAffirmations).sorted()
            return favs.isEmpty ? ["No favourites yet. Heart some affirmations to save them here."] : favs
        }

        let service = AffirmationService.shared
        let data = appState.onboardingData
        // Use user-picked categories if any, otherwise fall back to onboarding categories
        let categories = selectedCategories.isEmpty ? data.categories : Array(selectedCategories).filter { $0 != "Favourites" }
        // If religion is unchecked, force "general" to exclude religious content
        let belief = isReligionIncluded ? (data.beliefs.first ?? "general") : "general"
        let results = service.getAllMatchedAffirmations(
            categories: categories,
            goals: data.goals,
            belief: belief,
            name: data.name ?? ""
        )
        // Shuffle using session seed — different each app launch, stable during session
        var texts = results.map { $0.text }
        var rng = SeededRandomNumberGenerator(seed: UInt64(sessionSeed))
        texts.shuffle(using: &rng)
        return texts
    }

    private var currentTheme: MotivationTheme {
        defaultThemes.first(where: { $0.id == selectedThemeId }) ?? defaultThemes[0]
    }

    private func affirmationText(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 28, weight: .heavy))
            .foregroundStyle(Color(hex: currentTheme.textColor))
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .tracking(0.5)
            .padding(.horizontal, 32)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if currentTheme.type == "image" {
            GeometryReader { geo in
                Image(currentTheme.background)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
        } else if currentTheme.type == "gradient", let end = currentTheme.gradientEnd {
            LinearGradient(
                colors: [Color(hex: currentTheme.background), Color(hex: end)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        } else {
            Color(hex: currentTheme.background).ignoresSafeArea()
        }
    }

    var body: some View {
        ZStack {
            backgroundView
                .animation(.easeInOut(duration: 0.4), value: selectedThemeId)

            VStack(spacing: 0) {
                Spacer()

                // Affirmation text
                if !affirmations.isEmpty {
                    affirmationText(affirmations[currentIndex])
                        .id(currentIndex)
                        .transition(.asymmetric(
                            insertion: .offset(y: swipeDirection == .up ? 60 : -60).combined(with: .opacity),
                            removal: .offset(y: swipeDirection == .up ? -60 : 60).combined(with: .opacity)
                        ))
                        .offset(y: dragOffset * 0.15)
                        .opacity(1.0 - min(abs(dragOffset) / 300.0, 0.4))
                }

                Spacer()

                // Bottom action bar - centered share and heart
                HStack(spacing: 40) {
                    Button(action: shareAffirmation) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: currentTheme.accentColor))
                    }

                    Button(action: {
                        toggleFavorite(at: currentIndex)
                    }) {
                        Image(systemName: isCurrentFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 24))
                            .foregroundColor(isCurrentFavorited ? Color(hex: "C75050") : Color(hex: currentTheme.accentColor))
                    }
                }
                .padding(.bottom, 60)

                // Bottom row with grid and paintbrush
                HStack {
                    ZStack(alignment: .topLeading) {
                        Button(action: { showCategoryPicker = true }) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: currentTheme.accentColor))
                                .frame(width: 50, height: 50)
                                .background(Color(hex: currentTheme.accentColor).opacity(0.15))
                                .clipShape(Circle())
                        }

                        if selectedCategories.isEmpty {
                            Text("NEW")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "FF6B9D"))
                                .cornerRadius(10)
                                .offset(x: -8, y: -8)
                        }
                    }

                    Spacer()

                    Button(action: { showThemePicker = true }) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: currentTheme.accentColor))
                            .frame(width: 50, height: 50)
                            .background(Color(hex: currentTheme.accentColor).opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                guard !affirmations.isEmpty, currentIndex < affirmations.count else { return }
                toggleFavorite(at: currentIndex)
                showHeartAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showHeartAnimation = false
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        if !affirmations.isEmpty {
                            if value.translation.height < -threshold || velocity < -100 {
                                // Swiped up → next quote
                                swipeDirection = .up
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    currentIndex = (currentIndex + 1) % affirmations.count
                                    dragOffset = 0
                                }
                            } else if value.translation.height > threshold || velocity > 100 {
                                // Swiped down → previous quote
                                swipeDirection = .down
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    currentIndex = currentIndex > 0 ? currentIndex - 1 : affirmations.count - 1
                                    dragOffset = 0
                                }
                            } else {
                                // Not enough distance, snap back
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    dragOffset = 0
                                }
                            }
                        } else {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                dragOffset = 0
                            }
                        }
                    }
            )

            // Heart animation overlay
            if showHeartAnimation {
                Image(systemName: isCurrentFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 80))
                    .foregroundColor(isCurrentFavorited ? Color(hex: "C75050") : Color.white.opacity(0.8))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showHeartAnimation)
            }
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerSheet(selectedThemeId: $selectedThemeId, isPresented: $showThemePicker)
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                selectedCategoriesData: $selectedCategoriesData,
                isPresented: $showCategoryPicker,
                userBelief: appState.onboardingData.beliefs.first ?? "general",
                favoriteCount: favoriteAffirmations.count,
                onDismiss: {
                    currentIndex = 0
                }
            )
        }
        .onAppear {
            // Seed categories from onboarding selections on first use
            if !hasInitializedCategories && !appState.onboardingData.categories.isEmpty {
                let onboardingCategories = Set(appState.onboardingData.categories)
                if let data = try? JSONEncoder().encode(onboardingCategories) {
                    selectedCategoriesData = data
                }
                hasInitializedCategories = true
            }

            // Start at a random quote each time the tab appears
            if !affirmations.isEmpty {
                currentIndex = Int.random(in: 0..<affirmations.count)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    private func shareAffirmation() {
        guard !affirmations.isEmpty, currentIndex < affirmations.count else { return }
        let text = affirmations[currentIndex]
        let image = renderAffirmationImage(text: text, theme: currentTheme)
        shareImage = image
        showShareSheet = true
    }

    @MainActor
    private func renderAffirmationImage(text: String, theme: MotivationTheme) -> UIImage {
        let shareView = ShareAffirmationView(text: text, theme: theme)
        let renderer = ImageRenderer(content: shareView)
        renderer.scale = 3.0 // High resolution
        return renderer.uiImage ?? UIImage()
    }

    private var isCurrentFavorited: Bool {
        guard !affirmations.isEmpty, currentIndex < affirmations.count else { return false }
        return favoriteAffirmations.contains(affirmations[currentIndex])
    }

    private func toggleFavorite(at index: Int) {
        guard !affirmations.isEmpty, index < affirmations.count else { return }
        let text = affirmations[index]
        // Don't allow favoriting the empty-state message
        guard text != "No favourites yet. Heart some affirmations to save them here." else { return }
        var favs = favoriteAffirmations
        if favs.contains(text) {
            favs.remove(text)
            // If showing favourites and we just removed the last one, or current index is out of bounds, reset
            if isShowingFavorites {
                let remaining = favs.count
                if remaining == 0 {
                    currentIndex = 0
                } else if currentIndex >= remaining {
                    currentIndex = max(0, remaining - 1)
                }
            }
        } else {
            favs.insert(text)
        }
        saveFavorites(favs)
    }
}

// MARK: - Theme Picker Sheet

struct ThemePickerSheet: View {
    @Binding var selectedThemeId: String
    @Binding var isPresented: Bool
    @State private var collapsedSections: Set<String> = []

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "D0D0D0"))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            HStack {
                Text("Choose Theme")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "999999"))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "F0F0F0"))
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Grouped Theme Sections
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(themeSections) { section in
                        VStack(spacing: 0) {
                            // Section header (tap to collapse/expand)
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if collapsedSections.contains(section.id) {
                                        collapsedSections.remove(section.id)
                                    } else {
                                        collapsedSections.insert(section.id)
                                    }
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: section.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "666666"))

                                    Text(section.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color(hex: "1A1A1A"))

                                    Text("(\(section.themes.count))")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(hex: "999999"))

                                    Spacer()

                                    Image(systemName: collapsedSections.contains(section.id) ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(hex: "CCCCCC"))
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            // Grid content
                            if !collapsedSections.contains(section.id) {
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(section.themes) { theme in
                                        ThemePreviewCell(
                                            theme: theme,
                                            isSelected: selectedThemeId == theme.id,
                                            onTap: {
                                                selectedThemeId = theme.id
                                            }
                                        )
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "F8F8F8"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Theme Preview Cell

struct ThemePreviewCell: View {
    let theme: MotivationTheme
    let isSelected: Bool
    let onTap: () -> Void

    @ViewBuilder
    private var previewBackground: some View {
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

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    previewBackground
                        .frame(height: 100)
                        .cornerRadius(14)

                    Text("Aa")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(Color(hex: theme.textColor))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color(hex: "1A1A1A") : Color(hex: "EBEBEB"), lineWidth: isSelected ? 3 : 1.5)
                )

                Text(theme.name)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    @Binding var selectedCategoriesData: Data
    @Binding var isPresented: Bool
    var userBelief: String // e.g., "christianity", "islam", "general"
    var favoriteCount: Int
    var onDismiss: () -> Void

    @State private var localSelection: Set<String> = []
    @State private var includeReligious: Bool = true

    private let allCategories: [String] = [
        "Anxiety", "Morning", "Feeling sassy", "Self-love", "Overthinking",
        "Attraction", "Gratitude", "Purpose", "Dream big", "Confidence",
        "Self-talk", "Positivity", "Romance", "Inner child"
    ]

    private let categoryEmojis: [String: String] = [
        "Favourites": "❤️",
        "Anxiety": "😮‍💨", "Morning": "🌅", "Feeling sassy": "💅",
        "Self-love": "💖", "Overthinking": "🧠", "Attraction": "🧲",
        "Gratitude": "🙏", "Purpose": "🎯", "Dream big": "✨",
        "Confidence": "💪", "Self-talk": "🗣", "Positivity": "☀️",
        "Romance": "💕", "Inner child": "🧸"
    ]

    private let beliefEmojis: [String: String] = [
        "christianity": "✝️", "islam": "☪️", "judaism": "✡️",
        "buddhism": "☸️", "hinduism": "🕉️", "spiritual": "🔮"
    ]

    private var beliefDisplayName: String {
        userBelief.prefix(1).uppercased() + userBelief.dropFirst()
    }

    private var hasReligion: Bool {
        userBelief != "general" && !userBelief.isEmpty
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "D0D0D0"))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Categories")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Text(localSelection.isEmpty ? "Showing all affirmations" : "\(localSelection.count) selected")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "999999"))
                }

                Spacer()

                Button(action: {
                    saveAndDismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Category grid
            ScrollView {
                VStack(spacing: 10) {
                    // Favourites category (always shown first, full width)
                    Button(action: {
                        if localSelection.contains("Favourites") {
                            localSelection.remove("Favourites")
                        } else {
                            // When selecting Favourites, clear other selections
                            localSelection.removeAll()
                            localSelection.insert("Favourites")
                        }
                    }) {
                        HStack(spacing: 10) {
                            Text("❤️")
                                .font(.system(size: 20))

                            Text("Favourites")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(localSelection.contains("Favourites") ? .white : Color(hex: "1A1A1A"))
                                .lineLimit(1)

                            Spacer()

                            Text("\(favoriteCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(localSelection.contains("Favourites") ? .white.opacity(0.7) : Color(hex: "999999"))
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(localSelection.contains("Favourites") ? Color(hex: "C75050") : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(localSelection.contains("Favourites") ? Color.clear : Color(hex: "E0E0E0"), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    // Religion toggle (if user has one)
                    if hasReligion {
                        Button(action: {
                            includeReligious.toggle()
                        }) {
                            HStack(spacing: 10) {
                                Text(beliefEmojis[userBelief] ?? "🙏")
                                    .font(.system(size: 20))

                                Text(beliefDisplayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(includeReligious ? .white : Color(hex: "1A1A1A"))
                                    .lineLimit(1)

                                Spacer()

                                if includeReligious {
                                    Text("40%")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(includeReligious ? Color(hex: "1A1A1A") : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(includeReligious ? Color.clear : Color(hex: "E0E0E0"), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(allCategories, id: \.self) { category in
                            let isSelected = localSelection.contains(category)
                            Button(action: {
                                // Deselect Favourites when picking regular categories
                                localSelection.remove("Favourites")
                                if isSelected {
                                    localSelection.remove(category)
                                } else {
                                    localSelection.insert(category)
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Text(categoryEmojis[category] ?? "")
                                        .font(.system(size: 20))

                                    Text(category)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(isSelected ? .white : Color(hex: "1A1A1A"))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isSelected ? Color(hex: "1A1A1A") : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.clear : Color(hex: "E0E0E0"), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)

                // Clear selection button
                if !localSelection.isEmpty || !includeReligious {
                    Button(action: {
                        localSelection.removeAll()
                        includeReligious = hasReligion
                    }) {
                        Text("Clear All")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "999999"))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color(hex: "F8F8F8"))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            if let decoded = try? JSONDecoder().decode(Set<String>.self, from: selectedCategoriesData) {
                var cats = decoded
                // Restore religion flag
                if cats.contains("__religion_excluded__") {
                    includeReligious = false
                    cats.remove("__religion_excluded__")
                } else if cats.contains("__religion_included__") {
                    includeReligious = true
                    cats.remove("__religion_included__")
                } else {
                    includeReligious = hasReligion // default: on if they have a religion
                }
                localSelection = cats
            }
        }
    }

    private func saveAndDismiss() {
        // Store religion flag as a special key in the categories set
        var toSave = localSelection
        // Remove any previous religion marker
        toSave.remove("__religion_included__")
        toSave.remove("__religion_excluded__")
        if hasReligion {
            toSave.insert(includeReligious ? "__religion_included__" : "__religion_excluded__")
        }
        if let data = try? JSONEncoder().encode(toSave) {
            selectedCategoriesData = data
        }
        isPresented = false
        onDismiss()
    }
}

// MARK: - Share Affirmation Render View

struct ShareAffirmationView: View {
    let text: String
    let theme: MotivationTheme

    var body: some View {
        ZStack {
            // Background
            if theme.type == "image" {
                Image(theme.background)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 1080, height: 1920)
                    .clipped()
            } else if theme.type == "gradient", let end = theme.gradientEnd {
                LinearGradient(
                    colors: [Color(hex: theme.background), Color(hex: end)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(hex: theme.background)
            }

            // Dark overlay
            Color.black.opacity(0.15)

            // Content
            VStack(spacing: 40) {
                Spacer()

                Text(text.uppercased())
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundColor(Color(hex: theme.textColor))
                    .multilineTextAlignment(.center)
                    .lineSpacing(16)
                    .tracking(1.0)
                    .padding(.horizontal, 80)

                Text("Be You")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color(hex: theme.textColor).opacity(0.5))

                Spacer()
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Seeded Random Number Generator

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
