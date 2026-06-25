import SwiftUI

struct AlarmDismissFlowView: View {
    let alarmId: UUID
    let alarmName: String
    let missions: [String]          // one or two missions, completed in order
    let selectedItems: [String]
    let onDismissed: () -> Void

    @State private var didRecord = false
    @State private var showIntro = true
    @State private var currentIndex = 0
    @State private var showCompletion = false
    @State private var startTime = Date()
    /// When the alarm flow first appeared (≈ alarm fired). Not reset, so it measures
    /// the full response time from the start of the alarm to mission completion.
    @State private var firedAt = Date()
    /// Elapsed time (alarm start → completion), frozen at the moment missions finish.
    @State private var completedElapsed: TimeInterval = 0
    @State private var didTrackFired = false
    @State private var missionStartedAt = Date()

    private var activeMission: String {
        missions.indices.contains(currentIndex) ? missions[currentIndex] : "Item Search"
    }

    /// The wake-up check goes straight to the typing screen (no intro).
    private var isWakeUpCheck: Bool { missions == ["Type Word"] }

    var body: some View {
        if showIntro && !isWakeUpCheck {
            MissionIntroView(missionType: missions.joined(separator: " + ")) {
                withAnimation {
                    showIntro = false
                    startTime = Date()
                }
            }
            .transition(.opacity)
            .onAppear { trackFiredOnce() }
        } else if showCompletion {
            completionView
        } else {
            missionView(for: activeMission)
                .id(currentIndex) // fresh view instance per mission in the chain
                .onAppear {
                    trackFiredOnce()
                    missionStartedAt = Date()
                    AnalyticsManager.shared.trackMissionStarted(
                        mission: activeMission,
                        index: currentIndex,
                        ofCount: missions.count
                    )
                }
        }
    }

    private func trackFiredOnce() {
        guard !didTrackFired else { return }
        didTrackFired = true
        AnalyticsManager.shared.trackAlarmFired(alarmId: alarmId, missions: missions)
    }

    @ViewBuilder
    private func missionView(for mission: String) -> some View {
        switch mission {
        case "Item Search":
            ItemSearchMissionView(
                items: selectedItems.isEmpty ? defaultItems : selectedItems,
                onMissionComplete: advanceOrComplete
            )
        case "Picture of Sky":
            PhotoMissionView(
                missionTitle: "Take a Picture of the Sky",
                missionDescription: "Go outside and snap a photo of the sky",
                missionEmoji: "🌅",
                missionName: "Picture of Sky",
                onMissionComplete: advanceOrComplete
            )
        case "Make Your Bed":
            PhotoMissionView(
                missionTitle: "Make Your Bed",
                missionDescription: "Make your bed and take a photo",
                missionEmoji: "🛏️",
                missionName: "Make Your Bed",
                onMissionComplete: advanceOrComplete
            )
        case "Touch Grass":
            PhotoMissionView(
                missionTitle: "Touch Grass",
                missionDescription: "Go outside and take a photo of nature",
                missionEmoji: "🌿",
                missionName: "Touch Grass",
                onMissionComplete: advanceOrComplete
            )
        case "Solve Math":
            SolveMathMissionView(onMissionComplete: advanceOrComplete)
        case "Type Word":
            TypeWordMissionView(word: selectedItems.first ?? "Morning", onMissionComplete: advanceOrComplete)
        default:
            ItemSearchMissionView(
                items: defaultItems,
                onMissionComplete: advanceOrComplete
            )
        }
    }

    /// Called when the current mission's activity finishes. Advances to the next mission,
    /// or records completion and shows the final screen if this was the last one.
    private func advanceOrComplete() {
        AnalyticsManager.shared.trackMissionCompleted(
            mission: activeMission,
            secondsTaken: Int(Date().timeIntervalSince(missionStartedAt))
        )
        if currentIndex < missions.count - 1 {
            withAnimation { currentIndex += 1 }
        } else {
            recordCompletion()
            withAnimation { showCompletion = true }
        }
    }

    /// Stops the alarm + cancels backups, and records progress. Idempotent.
    private func recordCompletion() {
        guard !didRecord else { return }
        didRecord = true

        MissionAlarmAudio.shared.stop()   // mission done → stop the continuous alarm loop

        // Resolve the alarm's sound BEFORE completeMission (it cancels backups, which deletes
        // the alarmBackupPrimary_ bridge key we need to map a backup back to its primary).
        let primaryId = UserDefaults.standard.string(forKey: "alarmBackupPrimary_\(alarmId.uuidString)") ?? alarmId.uuidString
        let sound = AlarmScheduler.loadAlarms().first(where: { $0.id.uuidString == primaryId })?.sound ?? "Default"

        AlarmScheduler.completeMission(firedAlarmId: alarmId)

        // Freeze the time-to-complete (alarm start → now) for the completion screen.
        completedElapsed = Date().timeIntervalSince(firedAt)

        // The wake-up check is a follow-up nudge, not a real wake-up — it shouldn't count
        // toward wakeups, the day streak, or the Insights stats.
        guard !isWakeUpCheck else { return }

        let wakeUps = UserDefaults.standard.integer(forKey: "totalWakeUps") + 1
        UserDefaults.standard.set(wakeUps, forKey: "totalWakeUps")

        // Capture whether this is the first completion today *before* recording it.
        let wasFirstToday = !AlarmCompletionStore.hasCompleted()

        // Records today for the streak + weekly trackers (Home & Insights).
        AlarmCompletionStore.markCompleted()

        // Decide whether to queue the "Write a Review" sheet (first 3 days, then every 5th).
        ReviewPromptManager.evaluate(
            wasFirstToday: wasFirstToday,
            distinctDays: AlarmCompletionStore.load().count,
            totalCompletions: wakeUps
        )

        // Records this wake-up for the Insights stat boxes (sound resolved above, pre-cleanup).
        AlarmStatsStore.record(
            wakeDate: firedAt,
            responseSeconds: Int(completedElapsed),
            missions: missions,
            sound: sound
        )

        // Analytics: the completed wake-up + refreshed user profile stats.
        AnalyticsManager.shared.trackAlarmCompleted(
            wakeTime: wakeUpTime(),
            secondsTaken: Int(completedElapsed),
            missions: missions,
            sound: sound,
            streak: AlarmCompletionStore.currentStreak()
        )
        AnalyticsManager.shared.syncWakeUpStats()

        // One positive nudge after the first completed mission of the day.
        NotificationManager.shared.sendDailyEncouragement()
    }

    // MARK: - Shared Completion Screen

    private var completionView: some View {
        VStack(spacing: 20) {
            Text("BeYou")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .padding(.top, 20)

            Spacer()

            Text("☀️").font(.system(size: 80))

            Text("Alarm turned off!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))

            Text("Great job starting your day right")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "888888"))

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    statCard(icon: "sunrise.fill", value: wakeUpTime(), label: "Wake Up Time")
                    statCard(icon: "timer", value: timeTaken(), label: "Time to Complete")
                }
                HStack(spacing: 16) {
                    statCard(icon: "flame.fill", value: "\(AlarmCompletionStore.currentStreak())", label: "Day Streak")
                    statCard(icon: "sun.max.fill", value: "\(UserDefaults.standard.integer(forKey: "totalWakeUps"))", label: "Wakeups")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            Button(action: onDismissed) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "1A1A1A"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F8F8F8").ignoresSafeArea())
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "666666"))
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "999999"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
        )
    }

    private func timeTaken() -> String {
        let elapsed = Int(completedElapsed)
        let m = elapsed / 60
        let s = elapsed % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private func wakeUpTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: firedAt)
    }

    private let defaultItems = [
        "Toothbrush", "Running Faucet", "Shoes", "Keys",
        "Coffee Mug", "Mirror", "Water Bottle", "Book"
    ]
}

// MARK: - Mission Intro

struct MissionIntroView: View {
    let missionType: String
    let onStart: () -> Void

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "BeYou"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(appName)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .padding(.top, 16)

            Spacer()

            Text("☀️")
                .font(.system(size: 96))

            Text("Time to Wake Up!")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .padding(.top, 28)

            Text("\(missionType) to turn off your alarm")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "888888"))
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: onStart) {
                Text("Start Mission")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color(hex: "1A1A1A"))
                    .cornerRadius(30)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F5F5F5").ignoresSafeArea())
    }
}

// MARK: - Photo Mission (Sky, Bed, Touch Grass)

struct PhotoMissionView: View {
    let missionTitle: String
    let missionDescription: String
    let missionEmoji: String
    var missionName: String = "Photo"
    let onMissionComplete: () -> Void

    @StateObject private var camera = CameraController()
    @State private var verifying = false
    @State private var verifyAttempts = 0
    @State private var verifyMessage: String?
    @State private var verifySuccess = false
    @State private var rejectionToken = 0
    @State private var capturedImage: UIImage?

    private var analyzingLabel: String {
        switch missionName {
        case "Make Your Bed": return "bed"
        case "Picture of Sky": return "sky"
        case "Touch Grass": return "grass"
        default: return "photo"
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()
            cameraView

            if let verifyMessage {
                Text(verifyMessage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background((verifySuccess ? Color(hex: "34C759") : Color.gray).opacity(0.92))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            }

            if verifying {
                AnalyzingOverlay(image: capturedImage, label: analyzingLabel)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private var cameraView: some View {
        VStack(spacing: 0) {
            Text("BeYou")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ZStack {
                CameraPreviewView(session: camera.session)
                    .cornerRadius(20)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                VStack {
                    HStack(spacing: 12) {
                        Text(missionEmoji)
                            .font(.system(size: 30))

                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1, height: 30)

                        Text(missionTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .padding(.top, 40)

                    Spacer()

                    Text(missionDescription)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 20)
                }
            }

            Spacer()

            Button(action: capture) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "1A1A1A"), lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(Color(hex: "1A1A1A"))
                        .frame(width: 60, height: 60)
                }
            }
            .disabled(verifying || verifySuccess)
            .padding(.bottom, 40)
        }
    }

    private func capture() {
        guard !verifying else { return }
        verifying = true
        withAnimation { verifyMessage = nil }

        camera.capturePhoto { data in
            guard let data, let image = UIImage(data: data) else {
                // No camera available (e.g. simulator) — accept.
                verifying = false
                onMissionComplete()
                return
            }
            capturedImage = image
            Task {
                let result = await MissionPhotoVerifier.verify(image: image, mission: missionName, target: nil)
                await MainActor.run {
                    verifyAttempts += 1
                    if result.pass {
                        // Correct → brief green confirmation, then advance.
                        MorningMemoryStore.add(image: image, missionName: missionName)
                        verifying = false
                        withAnimation { verifySuccess = true; verifyMessage = MissionPhotoVerifier.praise() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onMissionComplete() }
                    } else if verifyAttempts >= 3 {
                        // Fail open after 3 tries so the user is never trapped.
                        MorningMemoryStore.add(image: image, missionName: missionName)
                        verifying = false
                        onMissionComplete()
                    } else {
                        verifying = false
                        rejectionToken += 1
                        let token = rejectionToken
                        withAnimation {
                            verifySuccess = false
                            verifyMessage = MissionPhotoVerifier.friendlyRejection(mission: missionName, target: nil)
                        }
                        // Auto-dismiss the message so it doesn't linger.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            if rejectionToken == token {
                                withAnimation { verifyMessage = nil }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Solve Math Mission

struct SolveMathMissionView: View {
    let onMissionComplete: () -> Void

    private let total = 3
    @State private var solved = 0
    @State private var a = 0
    @State private var b = 0
    @State private var op = "+"
    @State private var answer = ""
    @State private var showWrong = false
    @FocusState private var focused: Bool

    private var correctAnswer: Int {
        switch op {
        case "-": return a - b
        case "×": return a * b
        default: return a + b
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { i in
                        Capsule()
                            .fill(i < solved ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Text("Solve \(total) to wake up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 14)

                Spacer()

                Text("\(a) \(op) \(b)")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundColor(.white)

                TextField("", text: $answer)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .focused($focused)
                    .frame(width: 180, height: 64)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(showWrong ? Color.red : Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .padding(.top, 24)

                Text(showWrong ? "Not quite — try again" : " ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.top, 10)

                Spacer()

                Button(action: check) {
                    Text("Submit")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            newProblem()
            focused = true
        }
    }

    private func newProblem() {
        op = ["+", "-", "×"].randomElement() ?? "+"
        switch op {
        case "-":
            a = Int.random(in: 30...99)
            b = Int.random(in: 1...a)
        case "×":
            a = Int.random(in: 2...12)
            b = Int.random(in: 2...12)
        default:
            a = Int.random(in: 10...49)
            b = Int.random(in: 10...49)
        }
        answer = ""
        showWrong = false
    }

    private func check() {
        guard let value = Int(answer) else {
            showWrong = true
            return
        }
        if value == correctAnswer {
            solved += 1
            if solved >= total {
                onMissionComplete()
            } else {
                newProblem()
                focused = true
            }
        } else {
            showWrong = true
            answer = ""
        }
    }
}
