import SwiftUI
import ManagedSettings

/// The flow shown when the user taps "Stop" on an active App Block. Based on the
/// meditation intervention (mood → affirmations → breathing → reflect), with a
/// "Why do you feel this way?" reason screen in place of the topic picker.
/// Completing it lifts the App Block.
@available(iOS 16.0, *)
struct AppBlockInterventionSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @Environment(\.dismiss) var dismiss

    enum Page {
        case moodCheck
        case reasonCheck
        case affirmation
        case breathing
        case reflect
    }

    @State private var currentPage: Page = .moodCheck
    @State private var selectedMood: MentalHealthMood?
    @State private var reasonOptions: [MoodReasonOption] = []
    @State private var selectedReason: MoodReasonOption?

    @State private var currentAffirmationIndex: Int = 0
    @State private var aiAffirmations: [String]?
    @State private var isLoadingAffirmations = false
    @AppStorage("interventionAffirmationCount") private var affirmationCount: Int = 3

    // Affirmation progress bar
    @State private var affirmationProgress: CGFloat = 0
    @State private var canAdvance = false
    @State private var progressTimer: Timer?

    // Breathing
    @State private var breathingPhase: String = "Breathe In"
    @State private var breathingScale: CGFloat = 0.6
    @State private var breathingTimeRemaining: Int = 15
    @State private var breathingTimer: Timer?

    // Voice / TTS
    @StateObject private var ttsService = TTSService.shared
    @AppStorage("selectedVoiceId") private var selectedVoiceId: String = "uIZsnBL0YK1S5j69bAih"
    @AppStorage("selectedVoiceName") private var selectedVoiceName: String = "Samantha"
    @AppStorage("ttsEnabled") private var ttsEnabled: Bool = true
    @State private var showVoicePicker = false

    // Theme
    @AppStorage("selectedMotivationTheme") private var selectedThemeId: String = "starry-mountains"
    @State private var showThemePicker = false

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

    private var affirmationsToShow: [String] {
        if let ai = aiAffirmations, !ai.isEmpty { return ai }
        if !isLoadingAffirmations { return localAffirmations }
        return []
    }

    private var localAffirmations: [String] {
        let service = AffirmationService.shared
        let categories = selectedReason?.categories ?? ["Self-love"]
        let data = appState.onboardingData
        let belief = data.religion ?? data.beliefs.first ?? "general"
        return service.getDailyAffirmations(
            categories: categories,
            belief: belief,
            name: data.name ?? "",
            count: affirmationCount
        ).map { $0.text }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if currentPage == .affirmation {
                    themedBackground
                        .animation(.easeInOut(duration: 0.4), value: selectedThemeId)
                } else if currentPage == .breathing || currentPage == .reflect {
                    LinearGradient(
                        colors: [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
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
                    case .moodCheck:    moodCheckPage
                    case .reasonCheck:  reasonCheckPage
                    case .affirmation:  affirmationPage
                    case .breathing:    breathingPage
                    case .reflect:      reflectPage
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(
                            currentPage == .affirmation
                            ? Color(hex: currentTheme.accentColor)
                            : (currentPage == .breathing || currentPage == .reflect)
                                ? .white.opacity(0.6) : Color(hex: "64748B")
                        )
                }
            }
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Mood Check

    private var moodCheckPage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Image("be-you-icon")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(20)
                        .padding(.top, 40)

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

                    VStack(spacing: 12) {
                        ForEach(MentalHealthMood.allCases, id: \.self) { mood in
                            MoodButton(
                                mood: mood,
                                isSelected: selectedMood == mood,
                                onTap: {
                                    selectedMood = mood
                                    selectedReason = nil
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            Button(action: {
                if let mood = selectedMood {
                    reasonOptions = MoodReasonLibrary.randomReasons(for: mood)
                    withAnimation { currentPage = .reasonCheck }
                }
            }) {
                Text("Next")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedMood != nil ? Color(hex: "6C5CE7") : Color(hex: "CBD5E1"))
                    .cornerRadius(16)
            }
            .disabled(selectedMood == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Reason Check ("Why do you feel this way?")

    private var reasonCheckPage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Image("be-you-icon")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(20)
                        .padding(.top, 40)

                    VStack(spacing: 12) {
                        Text("Why do you feel")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "1E293B"))
                        Text("this way?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "1E293B"))
                        Text("This helps us pick the right words for you")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "64748B"))
                            .padding(.top, 8)
                    }
                    .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        ForEach(reasonOptions) { reason in
                            Button(action: { selectedReason = reason }) {
                                HStack(spacing: 14) {
                                    Text(reason.emoji)
                                        .font(.system(size: 26))
                                    Text(reason.text)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(selectedReason == reason ? .white : Color(hex: "1E293B"))
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedReason == reason ? Color(hex: "6C5CE7") : Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selectedReason == reason ? Color.clear : Color(hex: "E2E8F0"), lineWidth: 1.5)
                                        )
                                )
                            }
                            .buttonStyle(HapticButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            Button(action: {
                if selectedReason != nil {
                    ttsService.clearCache()
                    currentAffirmationIndex = 0
                    aiAffirmations = nil
                    loadAIAffirmations()
                    withAnimation { currentPage = .affirmation }
                }
            }) {
                Text("Begin")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedReason != nil ? Color(hex: "6C5CE7") : Color(hex: "CBD5E1"))
                    .cornerRadius(16)
            }
            .disabled(selectedReason == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Affirmation Page

    private var affirmationPage: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(0..<affirmationCount, id: \.self) { index in
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: currentTheme.accentColor).opacity(0.3))
                                    .frame(height: 3)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: currentTheme.textColor))
                                    .frame(
                                        width: index < currentAffirmationIndex
                                            ? geo.size.width
                                            : (index == currentAffirmationIndex ? geo.size.width * affirmationProgress : 0),
                                        height: 3
                                    )
                            }
                        }
                        .frame(height: 3)
                    }
                }

                Button(action: { showVoicePicker = true }) {
                    Image(systemName: ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: currentTheme.accentColor))
                        .frame(width: 36, height: 36)
                        .background(Color(hex: currentTheme.accentColor).opacity(0.15))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Text(!canAdvance ? "Read and reflect..." : "Tap to continue")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: currentTheme.accentColor))
                .padding(.bottom, 8)
                .animation(.easeInOut, value: canAdvance)

            Spacer()

            if isLoadingAffirmations {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color(hex: currentTheme.textColor))
                    Text("Personalizing your affirmations...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: currentTheme.textColor).opacity(0.6))
                }
            } else if currentAffirmationIndex < affirmationsToShow.count {
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
        .contentShape(Rectangle())
        .onTapGesture {
            guard canAdvance else { return }
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.3)) {
                if currentAffirmationIndex < affirmationCount - 1 {
                    currentAffirmationIndex += 1
                    startProgressTimer()
                    playAffirmationAudio(index: currentAffirmationIndex)
                    prefetchNextAudio(after: currentAffirmationIndex)
                } else {
                    ttsService.clearCache()
                    progressTimer?.invalidate()
                    currentPage = .breathing
                }
            }
        }
        .onAppear {
            startProgressTimer()
            if !isLoadingAffirmations {
                playAffirmationAudio(index: 0)
                prefetchNextAudio(after: 0)
            }
        }
        .sheet(isPresented: $showVoicePicker) {
            VoicePickerSheet(
                selectedVoiceId: $selectedVoiceId,
                selectedVoiceName: $selectedVoiceName,
                ttsEnabled: $ttsEnabled,
                isPresented: $showVoicePicker
            )
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerSheet(selectedThemeId: $selectedThemeId, isPresented: $showThemePicker)
        }
        .onDisappear {
            ttsService.stop()
        }
    }

    // MARK: - Breathing Page

    private var breathingPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Text(breathingPhase)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .animation(.easeInOut, value: breathingPhase)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "6C5CE7").opacity(0.6), Color(hex: "6C5CE7").opacity(0.1)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(breathingScale)
                .animation(.easeInOut(duration: 4), value: breathingScale)

            Text("\(breathingTimeRemaining)s")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Text("Focus on your breath")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.bottom, 40)
        }
        .onAppear { startBreathingExercise() }
        .onDisappear { breathingTimer?.invalidate() }
    }

    // MARK: - Reflect Page

    private var reflectPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "6C5CE7"))

            Text("You're all set")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)

            Text("Your apps are unlocked. Use your time well.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: completeUnblock) {
                Text("Unlock Apps")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "0F0C29"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func loadAIAffirmations() {
        isLoadingAffirmations = true
        aiAffirmations = nil

        Task {
            let data = appState.onboardingData
            let mood = selectedMood?.rawValue ?? "Okay"
            let feeling = selectedReason?.text
            let religion = data.religion ?? data.beliefs.first

            let result = await AIAffirmationService.shared.generateAffirmations(
                mood: mood,
                feeling: feeling,
                name: data.name,
                religion: religion,
                count: affirmationCount
            )

            await MainActor.run {
                if let result = result { aiAffirmations = result }
                isLoadingAffirmations = false
                if currentPage == .affirmation {
                    playAffirmationAudio(index: 0)
                    prefetchNextAudio(after: 0)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if isLoadingAffirmations { isLoadingAffirmations = false }
        }
    }

    private func startProgressTimer() {
        canAdvance = false
        affirmationProgress = 0
        progressTimer?.invalidate()
        let interval: TimeInterval = 0.05
        let duration: TimeInterval = 3.0
        let increment = interval / duration

        progressTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            affirmationProgress += increment
            if affirmationProgress >= 1.0 {
                affirmationProgress = 1.0
                canAdvance = true
                timer.invalidate()
            }
        }
    }

    private func startBreathingExercise() {
        breathingTimeRemaining = 15
        breathingPhase = "Breathe In"
        breathingScale = 1.0

        breathingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            breathingTimeRemaining -= 1
            let elapsed = 15 - breathingTimeRemaining
            if elapsed % 8 < 4 {
                breathingPhase = "Breathe In"
                breathingScale = 1.0
            } else {
                breathingPhase = "Breathe Out"
                breathingScale = 0.6
            }
            if breathingTimeRemaining <= 0 {
                timer.invalidate()
                withAnimation { currentPage = .reflect }
            }
        }
    }

    // MARK: - Audio

    private func playAffirmationAudio(index: Int) {
        guard ttsEnabled, index < affirmationsToShow.count else { return }
        let text = affirmationsToShow[index]
        Task {
            if let data = await ttsService.getAudio(text: text, voiceId: selectedVoiceId, index: index) {
                await MainActor.run { ttsService.play(data: data) }
            }
        }
    }

    private func prefetchNextAudio(after index: Int) {
        let nextIndex = index + 1
        guard nextIndex < affirmationsToShow.count else { return }
        ttsService.prefetch(text: affirmationsToShow[nextIndex], voiceId: selectedVoiceId, index: nextIndex)
    }

    private func completeUnblock() {
        screenTimeManager.deactivateAppBlock()
        AnalyticsManager.shared.track("App Block Unlocked")
        dismiss()
    }
}
