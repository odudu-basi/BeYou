import SwiftUI

struct OnboardingDemoView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    enum DemoPage {
        case intro
        case moodCheck
        case reasonCheck
        case affirmation
    }

    @State private var demoPage: DemoPage = .intro

    // Intro fade-in states
    @State private var showLine1 = false
    @State private var showLine2 = false
    @State private var showLine3 = false
    @State private var showContinue = false

    // Demo states
    @State private var selectedMood: MentalHealthMood?
    @State private var selectedReason: MoodReason?
    @State private var currentAffirmationIndex: Int = 0
    @State private var affirmationProgress: CGFloat = 0
    @State private var canAdvance = false
    @State private var progressTimer: Timer?

    // Voice / TTS
    @StateObject private var ttsService = TTSService.shared
    @AppStorage("selectedVoiceId") private var selectedVoiceId: String = "uIZsnBL0YK1S5j69bAih"
    @AppStorage("selectedVoiceName") private var selectedVoiceName: String = "Samantha"
    @AppStorage("ttsEnabled") private var ttsEnabled: Bool = true
    @State private var showVoicePicker = false

    private var demoAffirmations: [String] {
        guard let reason = selectedReason else {
            return [
                "I AM WORTHY OF A LIFE BEYOND MY SCREEN",
                "I CHOOSE TO BE PRESENT IN THIS MOMENT",
                "I AM STRONGER THAN MY HABITS"
            ]
        }
        return Self.affirmationsByReason[reason] ?? [
            "I AM WORTHY OF A LIFE BEYOND MY SCREEN",
            "I CHOOSE TO BE PRESENT IN THIS MOMENT",
            "I AM STRONGER THAN MY HABITS"
        ]
    }

    private static let affirmationsByReason: [MoodReason: [String]] = [
        // GREAT
        .feelingConfident: [
            "I AM RADIATING CONFIDENCE AND IT SHOWS",
            "I TRUST MYSELF AND MY ABILITIES COMPLETELY",
            "I WAS BUILT FOR THIS MOMENT"
        ],
        .excitedAboutFuture: [
            "MY FUTURE IS BRIGHT AND FULL OF POSSIBILITY",
            "EVERY STEP I TAKE BRINGS ME CLOSER TO MY DREAMS",
            "I AM CREATING A LIFE I'M PROUD OF"
        ],
        .gratefulForPeople: [
            "I AM SURROUNDED BY LOVE AND IT FILLS ME UP",
            "THE PEOPLE IN MY LIFE MAKE ME BETTER",
            "I DESERVE THE LOVE I RECEIVE"
        ],
        .ridingGoodEnergy: [
            "THIS ENERGY IS MINE AND I OWN IT",
            "I ATTRACT GOOD THINGS INTO MY LIFE",
            "I AM VIBRATING AT MY HIGHEST FREQUENCY"
        ],
        .feelingLikeThat: [
            "I AM THAT PERSON AND I KNOW IT",
            "NOBODY CAN TAKE THIS FEELING FROM ME",
            "I WAS BORN TO STAND OUT AND SHINE"
        ],

        // GOOD
        .goodDay: [
            "TODAY IS A GIFT AND I'M MAKING THE MOST OF IT",
            "I CHOOSE TO SEE THE GOOD IN THIS DAY",
            "EVERY GOOD DAY STARTS WITH A GRATEFUL HEART"
        ],
        .feelingPositive: [
            "MY POSITIVE MINDSET IS MY SUPERPOWER",
            "I CHOOSE THOUGHTS THAT LIFT ME HIGHER",
            "GOOD THINGS ARE FLOWING MY WAY"
        ],
        .makingProgress: [
            "EVERY SMALL STEP IS STILL A STEP FORWARD",
            "I AM PROUD OF HOW FAR I'VE COME",
            "MY PROGRESS IS PROOF THAT I'M CAPABLE"
        ],
        .feelingConnected: [
            "I AM LOVED AND I LOVE DEEPLY IN RETURN",
            "CONNECTION IS WHAT MAKES LIFE BEAUTIFUL",
            "I CHERISH THE BONDS THAT FILL MY HEART"
        ],
        .calmPeaceful: [
            "I AM AT PEACE WITH WHERE I AM RIGHT NOW",
            "STILLNESS IS MY STRENGTH",
            "I DESERVE THIS CALM AND I EMBRACE IT"
        ],

        // OKAY
        .gettingThrough: [
            "SHOWING UP IS ENOUGH AND I'M HERE",
            "EVEN ON ORDINARY DAYS I AM EXTRAORDINARY",
            "I GIVE MYSELF GRACE ON DAYS LIKE THIS"
        ],
        .feelingFlat: [
            "THIS FEELING IS TEMPORARY, MY WORTH IS NOT",
            "I DON'T NEED TO BE ON FIRE EVERY DAY",
            "EVEN IN STILLNESS I AM GROWING"
        ],
        .notBadNotGreat: [
            "IT'S OKAY TO JUST BE OKAY TODAY",
            "I HONOR WHERE I AM WITHOUT JUDGMENT",
            "BETTER DAYS ARE ALWAYS ON THEIR WAY"
        ],
        .distractedRestless: [
            "I AM LEARNING TO BE PRESENT ONE MOMENT AT A TIME",
            "MY MIND IS POWERFUL AND I CAN DIRECT IT",
            "I CHOOSE FOCUS OVER DISTRACTION"
        ],
        .couldUsePickMeUp: [
            "I AM MORE RESILIENT THAN I REALIZE",
            "THIS MOMENT DOES NOT DEFINE MY DAY",
            "I HAVE THE POWER TO SHIFT MY ENERGY"
        ],

        // NOT GREAT
        .lowEnergy: [
            "REST IS NOT WEAKNESS, IT IS WISDOM",
            "I AM ALLOWED TO TAKE THINGS SLOW TODAY",
            "MY ENERGY WILL RETURN AND I WILL RISE"
        ],
        .comparingToOthersNG: [
            "MY JOURNEY IS MINE AND IT'S BEAUTIFUL",
            "I AM ENOUGH EXACTLY AS I AM TODAY",
            "COMPARISON STEALS MY JOY BUT I'M TAKING IT BACK"
        ],
        .notGoodEnoughNG: [
            "I AM WORTHY EVEN WHEN I DON'T FEEL IT",
            "MY VALUE DOES NOT DEPEND ON MY PRODUCTIVITY",
            "I AM ENOUGH, PERIOD"
        ],
        .stressedAboutLife: [
            "I CAN HANDLE WHATEVER COMES MY WAY",
            "STRESS DOES NOT CONTROL ME, I CONTROL MY RESPONSE",
            "I RELEASE WHAT I CANNOT CHANGE"
        ],
        .roughDay: [
            "TOUGH DAYS BUILD TOUGHER PEOPLE",
            "TOMORROW IS A FRESH START WAITING FOR ME",
            "I AM PROUD OF MYSELF FOR GETTING THROUGH TODAY"
        ],

        // STRUGGLING
        .anxiousOverwhelmed: [
            "I BREATHE IN PEACE AND BREATHE OUT FEAR",
            "I AM SAFE IN THIS MOMENT RIGHT NOW",
            "MY ANXIETY DOES NOT DEFINE WHO I AM"
        ],
        .comparingToOthersS: [
            "I REFUSE TO MEASURE MY WORTH AGAINST ANYONE ELSE",
            "MY PATH IS UNIQUE AND THAT IS MY POWER",
            "I AM RUNNING MY OWN RACE AND I'M WINNING"
        ],
        .notGoodEnoughS: [
            "I AM WORTHY OF LOVE, SUCCESS, AND HAPPINESS",
            "THE VOICE THAT SAYS I'M NOT ENOUGH IS LYING",
            "I CHOOSE TO BELIEVE IN MYSELF TODAY"
        ],
        .lonelyDisconnected: [
            "I AM NEVER TRULY ALONE, I HAVE MYSELF",
            "CONNECTION IS COMING AND I AM OPEN TO IT",
            "I AM WORTHY OF DEEP, MEANINGFUL RELATIONSHIPS"
        ],
        .stuckInNegativeThoughts: [
            "MY THOUGHTS DO NOT CONTROL ME, I CONTROL THEM",
            "I CHOOSE TO REPLACE NEGATIVITY WITH TRUTH",
            "I AM BREAKING FREE FROM PATTERNS THAT DON'T SERVE ME"
        ]
    ]

    var body: some View {
        ZStack {
            switch demoPage {
            case .intro:
                introPage
            case .moodCheck:
                moodCheckPage
            case .reasonCheck:
                reasonCheckPage
            case .affirmation:
                affirmationPage
            }
        }
        .animation(.easeInOut(duration: 0.4), value: demoPage)
    }

    // MARK: - Intro Page

    private var introPage: some View {
        ZStack {
            Color(hex: "0A0A1A").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                Spacer()

                VStack(spacing: 32) {
                    Image("be-you-icon")
                        .resizable()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .opacity(showLine1 ? 1 : 0)

                    VStack(spacing: 20) {
                        Text("Here's how BeYou works")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(showLine1 ? 1 : 0)
                            .offset(y: showLine1 ? 0 : 15)

                        Text("The apps you choose are blocked until you say positive affirmations about yourself.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .opacity(showLine2 ? 1 : 0)
                            .offset(y: showLine2 ? 0 : 15)

                        Text("This helps you build the habit of speaking positively over yourself, every single day.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .opacity(showLine3 ? 1 : 0)
                            .offset(y: showLine3 ? 0 : 15)
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                if showContinue {
                    VStack(spacing: 12) {
                        Text("Let's try a quick demo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))

                        Button(action: {
                            withAnimation {
                                demoPage = .moodCheck
                            }
                        }) {
                            Text("Try It")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "0A0A1A"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer().frame(height: 36)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) { showLine1 = true }
            withAnimation(.easeOut(duration: 0.6).delay(1.2)) { showLine2 = true }
            withAnimation(.easeOut(duration: 0.6).delay(2.2)) { showLine3 = true }
            withAnimation(.easeOut(duration: 0.6).delay(3.2)) { showContinue = true }
        }
    }

    // MARK: - Mood Check Page

    private var moodCheckPage: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                // Demo label
                demoHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Image("be-you-icon")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(20)
                            .padding(.top, 24)

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
                                    onTap: { selectedMood = mood; selectedReason = nil }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }

                Button(action: {
                    if selectedMood != nil {
                        withAnimation { demoPage = .reasonCheck }
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
    }

    // MARK: - Reason Check Page

    private var reasonCheckPage: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                demoHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Image("be-you-icon")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(20)
                            .padding(.top, 24)

                        VStack(spacing: 12) {
                            Text("Why do you feel this way?")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "1E293B"))
                            Text("This helps us pick the right words for you")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "64748B"))
                                .padding(.top, 4)
                        }
                        .multilineTextAlignment(.center)

                        if let mood = selectedMood {
                            VStack(spacing: 12) {
                                ForEach(MoodReason.reasons(for: mood), id: \.self) { reason in
                                    ReasonButton(
                                        reason: reason,
                                        isSelected: selectedReason == reason,
                                        accentColor: mood.color,
                                        onTap: { selectedReason = reason }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                    }
                }

                Button(action: {
                    if selectedReason != nil {
                        withAnimation { demoPage = .affirmation }
                        startAffirmationTimer()
                    }
                }) {
                    Text("Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedReason != nil ? Color(hex: "3B82F6") : Color(hex: "CBD5E1"))
                        .cornerRadius(16)
                }
                .disabled(selectedReason == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Affirmation Page

    private var affirmationPage: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: progress bars + audio button
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach(0..<demoAffirmations.count, id: \.self) { index in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 3)

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white)
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

                    // Audio button
                    Button(action: { showVoicePicker = true }) {
                        Image(systemName: ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Demo label
                HStack {
                    Text("DEMO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Text(!canAdvance
                     ? "Read and reflect..."
                     : (currentAffirmationIndex < demoAffirmations.count - 1 ? "Tap to continue" : "Tap to finish"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 8)
                    .animation(.easeInOut, value: canAdvance)

                Spacer()

                Text(demoAffirmations[currentAffirmationIndex])
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .tracking(0.5)
                    .padding(.horizontal, 32)
                    .id(currentAffirmationIndex)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canAdvance else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                if currentAffirmationIndex < demoAffirmations.count - 1 {
                    currentAffirmationIndex += 1
                    resetAffirmationTimer()
                    playDemoAudio(index: currentAffirmationIndex)
                    prefetchNextDemoAudio(after: currentAffirmationIndex)
                } else {
                    ttsService.clearCache()
                    progressTimer?.invalidate()
                    onNext()
                }
            }
        }
        .onAppear {
            ttsService.clearCache()
            startAffirmationTimer()
            playDemoAudio(index: 0)
            prefetchNextDemoAudio(after: 0)
        }
        .sheet(isPresented: $showVoicePicker) {
            VoicePickerSheet(
                selectedVoiceId: $selectedVoiceId,
                selectedVoiceName: $selectedVoiceName,
                ttsEnabled: $ttsEnabled,
                isPresented: $showVoicePicker
            )
        }
        .onDisappear {
            ttsService.stop()
        }
    }

    // MARK: - Demo Header

    private var demoHeader: some View {
        HStack {
            Text("DEMO")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "6C5CE7"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "6C5CE7").opacity(0.1))
                .cornerRadius(6)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Timer Logic

    private func startAffirmationTimer() {
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

    private func resetAffirmationTimer() {
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

    // MARK: - Audio

    private func playDemoAudio(index: Int) {
        guard ttsEnabled, index < demoAffirmations.count else { return }
        let text = demoAffirmations[index]
        Task {
            if let data = await ttsService.getAudio(text: text, voiceId: selectedVoiceId, index: index) {
                await MainActor.run {
                    ttsService.play(data: data)
                }
            }
        }
    }

    private func prefetchNextDemoAudio(after index: Int) {
        let nextIndex = index + 1
        guard nextIndex < demoAffirmations.count else { return }
        ttsService.prefetch(text: demoAffirmations[nextIndex], voiceId: selectedVoiceId, index: nextIndex)
    }
}
