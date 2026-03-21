import SwiftUI
import ManagedSettings

@available(iOS 16.0, *)
struct InterventionSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @Environment(\.dismiss) var dismiss

    @State private var currentPage: InterventionPage = .mentalHealthCheck
    @State private var selectedMood: MentalHealthMood?
    @State private var currentAffirmationIndex: Int = 0
    @State private var showThemePicker = false
    @State private var selectedDuration: Int? = nil // For scheduled blocks
    @AppStorage("selectedMotivationTheme") private var selectedThemeId: String = "starry-mountains"
    @AppStorage("selectedAffirmationCategories") private var selectedCategoriesData: Data = Data()
    @AppStorage("interventionAffirmationCount") private var interventionCount: Int = 3

    private var blockType: String {
        SharedDataManager.shared.loadBlockType()
    }

    private var isScheduledBlock: Bool {
        blockType == "schedule"
    }

    private var selectedCategories: Set<String> {
        let raw = (try? JSONDecoder().decode(Set<String>.self, from: selectedCategoriesData)) ?? []
        return raw.filter { !$0.hasPrefix("__religion_") }
    }

    private var isReligionIncluded: Bool {
        let raw = (try? JSONDecoder().decode(Set<String>.self, from: selectedCategoriesData)) ?? []
        if raw.contains("__religion_excluded__") { return false }
        if raw.contains("__religion_included__") { return true }
        let belief = appState.onboardingData.beliefs.first ?? "general"
        return belief != "general"
    }

    /// The raw key used for functional operations (unlock, breakthrough recording, store lookup).
    /// This may be a token key like "app_123..." — never show this to the user directly.
    private var appKey: String {
        return appState.pendingAppToUnlock ?? "this app"
    }

    /// Display-safe app name — resolves token keys to human-readable names, falls back to "this app".
    private var appName: String {
        let raw = appKey
        if raw.hasPrefix("app_") {
            // Check storeKeyMapping
            let mapping = SharedDataManager.shared.loadStoreKeyMapping()
            for (displayName, tokenKey) in mapping {
                if tokenKey == raw { return displayName }
            }
            // Check if a migrated key exists in perAppIntentions with matching token data
            if let tokenIntention = appState.onboardingData.appIntention.perAppIntentions[raw],
               let tokenData = tokenIntention.appTokenData {
                for (key, intention) in appState.onboardingData.appIntention.perAppIntentions {
                    if !key.hasPrefix("app_"), let data = intention.appTokenData, data == tokenData {
                        return key
                    }
                }
            }
            // Never show raw token key to the user
            return "this app"
        }
        return raw
    }

    private var sessionMinutes: Int {
        // Try appKey first (token key), then appName (display name)
        if let intention = appState.onboardingData.appIntention.perAppIntentions[appKey] {
            return intention.minutesPerSession
        }
        if appKey != appName, let intention = appState.onboardingData.appIntention.perAppIntentions[appName] {
            return intention.minutesPerSession
        }
        return appState.onboardingData.appIntention.minutesPerSession
    }

    private var affirmationsToShow: [String] {
        let service = AffirmationService.shared
        let data = appState.onboardingData
        let userCategories = selectedCategories.isEmpty ? data.categories : Array(selectedCategories)
        let belief = isReligionIncluded ? (data.beliefs.first ?? "general") : "general"

        // Get the user's category pool
        let userPool = service.getAllMatchedAffirmations(
            categories: userCategories,
            goals: data.goals,
            belief: belief,
            name: data.name ?? ""
        ).map { $0.text }

        // Get mood-boosted pool (blended with user's mood selection)
        var moodPool: [String] = []
        if let mood = selectedMood {
            let moodCategories = mood.boostCategories
            moodPool = service.getAllMatchedAffirmations(
                categories: moodCategories,
                goals: data.goals,
                belief: belief,
                name: data.name ?? ""
            ).map { $0.text }
        }

        // Build the final pool: mood quotes first (prioritized), then user quotes
        // Deduplicate so overlapping quotes aren't shown twice
        var finalPool: [String] = []
        var seen = Set<String>()
        // Add mood-boosted quotes first (they get priority in picking)
        for q in moodPool where !seen.contains(q) {
            seen.insert(q)
            finalPool.append(q)
        }
        // Then add user category quotes
        for q in userPool where !seen.contains(q) {
            seen.insert(q)
            finalPool.append(q)
        }

        guard !finalPool.isEmpty else { return [] }

        // Pick quotes — mood quotes are at the front of finalPool so they're
        // naturally prioritized. Use breakthrough count as seed for variety.
        let seed = appState.appUsageStats.breakthroughsToday * 7 + 42
        var picks: [String] = []
        var usedIndices = Set<Int>()
        var s = seed

        // Pick ~2/3 from mood pool (front of array), ~1/3 from user pool (back)
        let moodCount = moodPool.isEmpty ? 0 : min(interventionCount - 1, finalPool.count)
        let moodEnd = min(moodPool.count, finalPool.count)

        // First: pick from mood section
        if moodEnd > 0 {
            while picks.count < moodCount && picks.count < moodEnd {
                s = (s &* 16807) % 2147483647
                let idx = abs(s) % moodEnd
                if !usedIndices.contains(idx) {
                    usedIndices.insert(idx)
                    picks.append(finalPool[idx])
                }
            }
        }

        // Then: fill remaining from the full pool
        while picks.count < interventionCount && picks.count < finalPool.count {
            s = (s &* 16807) % 2147483647
            let idx = abs(s) % finalPool.count
            if !usedIndices.contains(idx) {
                usedIndices.insert(idx)
                picks.append(finalPool[idx])
            }
        }

        return picks
    }

    private var currentTheme: MotivationTheme {
        defaultThemes.first(where: { $0.id == selectedThemeId }) ?? defaultThemes[0]
    }

    @ViewBuilder
    private var themedBackground: some View {
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
        NavigationView {
            ZStack {
                // Use themed bg on affirmation page, light gradient otherwise
                if currentPage == .affirmation {
                    themedBackground
                        .animation(.easeInOut(duration: 0.4), value: selectedThemeId)
                } else {
                    LinearGradient(
                        colors: [Color(hex: "F8FAFC"), Color(hex: "EEF2F6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }

                Group {
                    switch currentPage {
                    case .mentalHealthCheck:
                        mentalHealthCheckPage
                    case .affirmation:
                        affirmationPage
                    case .confirmContinue:
                        confirmContinuePage
                    case .unlock:
                        unlockPage
                    case .walkedAway:
                        walkedAwayPage
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        appState.isInterventionActive = false
                        appState.pendingAppToUnlock = nil
                        dismiss()
                    }
                    .foregroundColor(currentPage == .affirmation ? Color(hex: currentTheme.accentColor) : Color(hex: "64748B"))
                }
            }
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Mental Health Check Page

    private var mentalHealthCheckPage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // App logo
                    Image("be-you-icon")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(20)
                        .padding(.top, 40)

                    // Question
                    VStack(spacing: 12) {
                        Text("How are you feeling")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "1E293B"))

                        Text("right now?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "1E293B"))

                        Text("Take a moment to check in with yourself")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "64748B"))
                            .padding(.top, 8)
                    }
                    .multilineTextAlignment(.center)

                    // Mood options
                    VStack(spacing: 12) {
                        ForEach(MentalHealthMood.allCases, id: \.self) { mood in
                            MoodButton(
                                mood: mood,
                                isSelected: selectedMood == mood,
                                onTap: {
                                    selectedMood = mood
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            // Next button pinned to bottom
            Button(action: {
                if selectedMood != nil {
                    withAnimation {
                        currentPage = .affirmation
                    }
                }
            }) {
                Text("Next")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedMood != nil ? Color(hex: "3B82F6") : Color(hex: "CBD5E1"))
                    .cornerRadius(16)
            }
            .disabled(selectedMood == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Affirmation Page

    private var affirmationPage: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<interventionCount, id: \.self) { index in
                    Circle()
                        .fill(index <= currentAffirmationIndex
                              ? Color(hex: currentTheme.textColor)
                              : Color(hex: currentTheme.accentColor).opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            // "Tap to continue" hint
            Text(currentAffirmationIndex < interventionCount - 1 ? "Tap to continue" : "Tap to unlock")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: currentTheme.accentColor))
                .padding(.bottom, 8)

            Spacer()

            // Affirmation text — tap the whole area to advance
            if currentAffirmationIndex < affirmationsToShow.count {
                Text(affirmationsToShow[currentAffirmationIndex].uppercased())
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(Color(hex: currentTheme.textColor))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .tracking(0.5)
                    .padding(.horizontal, 32)
                    .id(currentAffirmationIndex)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            Spacer()

            // Bottom bar with paintbrush theme picker
            HStack {
                Spacer()

                Button(action: { showThemePicker = true }) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: currentTheme.accentColor))
                        .frame(width: 46, height: 46)
                        .background(Color(hex: currentTheme.accentColor).opacity(0.15))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                if currentAffirmationIndex < interventionCount - 1 {
                    currentAffirmationIndex += 1
                } else {
                    currentPage = .confirmContinue
                }
            }
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerSheet(selectedThemeId: $selectedThemeId, isPresented: $showThemePicker)
        }
    }

    // MARK: - Unlock Page

    private var unlockPage: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(Color(hex: "D1FAE5"))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "10B981"))
            }

            // Message
            VStack(spacing: 12) {
                Text("You've completed your")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "1E293B"))

                Text("mindful moment")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "1E293B"))

                Text("Use your time wisely")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
                    .padding(.top, 8)
            }
            .multilineTextAlignment(.center)

            Spacer()

            // Unlock button or duration picker (depending on block type)
            if isScheduledBlock {
                // Duration picker for scheduled blocks
                VStack(spacing: 16) {
                    Text("Choose session duration")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "64748B"))

                    // Grid of duration options
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach([5, 10, 20, 30], id: \.self) { minutes in
                            DurationButton(
                                minutes: minutes,
                                isSelected: selectedDuration == minutes,
                                onTap: {
                                    selectedDuration = minutes
                                    unlockApp()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            } else {
                // Fixed duration button for app intention blocks
                Button(action: unlockApp) {
                    VStack(spacing: 8) {
                        Text("Open the app")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("Unlocked for \(sessionMinutes) minutes")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Confirm Continue Page

    private var confirmContinuePage: some View {
        VStack(spacing: 32) {
            Spacer()

            // Question icon
            ZStack {
                Circle()
                    .fill(Color(hex: "FEF3C7"))
                    .frame(width: 100, height: 100)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "F59E0B"))
            }

            // Message
            VStack(spacing: 12) {
                Text("Are you sure you want")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "1E293B"))

                Text("to keep scrolling?")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "1E293B"))

                Text("You've just taken a mindful moment.\nDo you really need to open this app?")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .multilineTextAlignment(.center)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                // Green button — walk away
                Button(action: {
                    withAnimation {
                        currentPage = .walkedAway
                    }
                }) {
                    Text("No, I'm good")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "10B981"))
                        .cornerRadius(16)
                }

                // Red button — continue to unlock
                Button(action: {
                    withAnimation {
                        currentPage = .unlock
                    }
                }) {
                    Text("Yes, continue scrolling")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "EF4444"))
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Walked Away Page

    private var walkedAwayPage: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(Color(hex: "D1FAE5"))
                    .frame(width: 100, height: 100)

                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "10B981"))
            }

            // Message
            VStack(spacing: 12) {
                Text("You've completed your")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "1E293B"))

                Text("mindful moment")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "1E293B"))

                Text("Congratulations! You chose discipline\nover distraction.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .multilineTextAlignment(.center)

            Spacer()

            // Close button
            Button(action: walkAway) {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "059669")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func walkAway() {
        // Save mood entry (they still did the intervention)
        if let mood = selectedMood {
            let entry = MoodEntry(score: mood.score, date: Date(), appName: appName)
            SharedDataManager.shared.saveMoodEntry(entry)
        }

        // Reward discipline — record as a "nevermind" (walked away from temptation)
        appState.recordNevermind()

        // Track analytics
        AnalyticsManager.shared.track("Intervention Walk Away", properties: ["app": appName])

        // Clear intervention state without unlocking
        appState.isInterventionActive = false
        SharedDataManager.shared.saveInterventionActive(false)
        SharedDataManager.shared.savePendingAppToUnlock(nil)

        dismiss()
    }

    private func unlockApp() {
        print("🔓 INTERVENTION: Unlocking app: \(appName) (key: \(appKey))")

        // Get session duration - use selected duration for scheduled blocks, or app intention duration
        let sessionMinutes: Int
        if isScheduledBlock, let selected = selectedDuration {
            sessionMinutes = selected
            print("🔓 INTERVENTION: Scheduled block - using selected duration: \(sessionMinutes) minutes")
        } else {
            sessionMinutes = self.sessionMinutes
            print("🔓 INTERVENTION: Intention block - using app intention duration: \(sessionMinutes) minutes")
        }
        let sessionDuration = TimeInterval(sessionMinutes * 60)

        // Record breakthrough only for app intention blocks (not for scheduled blocks)
        // Use appKey for accurate matching against stored data
        if !isScheduledBlock {
            appState.recordBreakthrough(for: appKey)
        }

        // Save mood entry for mood tracking
        if let mood = selectedMood {
            let entry = MoodEntry(score: mood.score, date: Date(), appName: appName)
            SharedDataManager.shared.saveMoodEntry(entry)
        }

        appState.unlockApp(appName: appKey)

        // Track intervention completed
        AnalyticsManager.shared.trackInterventionCompleted(appName: appName, unlockDuration: sessionMinutes)

        // Get the app's token from the intention data
        // Try appKey (token key) first, then appName (display name), then storeKeyMapping
        var resolvedIntention = appState.onboardingData.appIntention.perAppIntentions[appKey]
        var storeKey = appKey

        if resolvedIntention == nil && appKey != appName {
            // Try display name
            resolvedIntention = appState.onboardingData.appIntention.perAppIntentions[appName]
            if resolvedIntention != nil {
                storeKey = appName
                print("🔓 INTERVENTION: Found intention via display name: '\(appName)'")
            }
        }

        if resolvedIntention == nil {
            // Try storeKeyMapping (display name -> token key)
            let mapping = SharedDataManager.shared.loadStoreKeyMapping()
            if let tokenKey = mapping[appName] {
                resolvedIntention = appState.onboardingData.appIntention.perAppIntentions[tokenKey]
                storeKey = tokenKey
                print("🔓 INTERVENTION: Found intention via storeKeyMapping: '\(appName)' -> '\(tokenKey)'")

                // Migrate in-memory data so future lookups work directly
                if let intent = resolvedIntention {
                    appState.onboardingData.appIntention.perAppIntentions[appName] = intent
                    appState.onboardingData.appIntention.perAppIntentions.removeValue(forKey: tokenKey)
                    SharedDataManager.shared.saveAppIntention(appState.onboardingData.appIntention)
                }
            }
        }

        // Also try matching by token data across all intentions
        if resolvedIntention == nil {
            for (key, intent) in appState.onboardingData.appIntention.perAppIntentions {
                if let _ = intent.appTokenData {
                    resolvedIntention = intent
                    storeKey = key
                    print("🔓 INTERVENTION: Found intention via token scan: key '\(key)'")
                    break
                }
            }
        }

        if let intention = resolvedIntention,
           let tokenData = intention.appTokenData,
           let token = try? JSONDecoder().decode(ApplicationToken.self, from: tokenData) {

            // ACTUALLY unlock by removing shields temporarily for THIS APP ONLY
            print("🔓 INTERVENTION: Removing shields for THIS APP ONLY for \(sessionMinutes) minutes")
            print("🔓 INTERVENTION: Using store key: \(storeKey)")
            screenTimeManager.temporarilyUnlockApp(forKey: storeKey, token: token, duration: sessionDuration)

        } else {
            print("⚠️ INTERVENTION: Could not decode token for \(appName) (key: \(appKey)), falling back to legacy unlock")
            // Fallback to old method if token can't be decoded
            screenTimeManager.temporarilyUnlockApps(for: sessionDuration)
        }

        // Clear intervention state
        appState.isInterventionActive = false
        SharedDataManager.shared.saveInterventionActive(false)
        SharedDataManager.shared.savePendingAppToUnlock(nil)

        print("✅ INTERVENTION: App unlocked! Session will last \(sessionMinutes) minutes")

        // Dismiss sheet
        dismiss()

        // Show success message to user
        // (They can now go back and open the app)
    }
}

// MARK: - Mental Health Mood Enum

enum MentalHealthMood: String, CaseIterable {
    case great = "Great"
    case good = "Good"
    case okay = "Okay"
    case notGreat = "Not Great"
    case struggling = "Struggling"

    /// Categories to boost in the intervention affirmation pool based on mood
    var boostCategories: [String] {
        switch self {
        case .struggling: return ["Self-love", "Anxiety", "Inner child", "Positivity"]
        case .notGreat:   return ["Self-love", "Anxiety", "Gratitude", "Self-talk"]
        case .okay:       return ["Gratitude", "Self-talk", "Purpose", "Positivity"]
        case .good:       return ["Confidence", "Dream big", "Attraction", "Purpose"]
        case .great:      return ["Feeling sassy", "Dream big", "Purpose", "Confidence"]
        }
    }

    /// Mood score for tracking (1 = struggling, 5 = great)
    var score: Int {
        switch self {
        case .struggling: return 1
        case .notGreat: return 2
        case .okay: return 3
        case .good: return 4
        case .great: return 5
        }
    }

    var emoji: String {
        switch self {
        case .great: return "😊"
        case .good: return "🙂"
        case .okay: return "😐"
        case .notGreat: return "😔"
        case .struggling: return "😞"
        }
    }

    var color: String {
        switch self {
        case .great: return "10B981" // Green
        case .good: return "3B82F6" // Blue
        case .okay: return "F59E0B" // Amber
        case .notGreat: return "EF4444" // Red
        case .struggling: return "DC2626" // Dark red
        }
    }
}

// MARK: - Intervention Page Enum

enum InterventionPage {
    case mentalHealthCheck
    case affirmation
    case confirmContinue
    case unlock
    case walkedAway
}

// MARK: - Mood Button Component

struct MoodButton: View {
    let mood: MentalHealthMood
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Emoji
                Text(mood.emoji)
                    .font(.system(size: 32))

                // Label
                Text(mood.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "1E293B"))

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: mood.color))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color(hex: mood.color) : Color(hex: "E2E8F0"), lineWidth: isSelected ? 2.5 : 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Duration Button Component

struct DurationButton: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text("\(minutes)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(isSelected ? .white : Color(hex: "1E293B"))

                Text("minutes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : Color(hex: "64748B"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ?
                          LinearGradient(
                              colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing
                          ) :
                          LinearGradient(
                              colors: [Color.white, Color.white],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing
                          )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.clear : Color(hex: "E2E8F0"), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
