import SwiftUI

// MARK: - Per-Mission "why this wakes you up" Screen (Screen 22)

/// One screen that explains whichever wake-up mission the user picked.
struct Onboarding2MissionInfoView: View {
    let missionName: String
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        let info = Self.info(for: missionName)
        return Onboarding2Template(
            title: info.title,
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: true,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 0) {
                Text(info.tagline)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "888888"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(height: 40)

                graphic(for: missionName, info: info)

                Spacer().frame(height: 30)

                Text(info.body)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "888888"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
        }
    }

    @ViewBuilder
    private func graphic(for mission: String, info: MissionInfo) -> some View {
        if mission == "Item Search" {
            ZStack {
                ViewfinderShape()
                    .stroke(Color(hex: "1A1A1A"), lineWidth: 3)
                    .frame(width: 200, height: 160)
                HStack(spacing: 16) {
                    Text("☕").font(.system(size: 40))
                    Text("🪥").font(.system(size: 40))
                    Text("🍌").font(.system(size: 40))
                }
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(info.tint.opacity(0.15))
                    .frame(width: 160, height: 160)
                Image(systemName: info.icon)
                    .font(.system(size: 64))
                    .foregroundColor(info.tint)
            }
        }
    }

    struct MissionInfo {
        let title: String
        let tagline: String
        let body: String
        let icon: String
        let tint: Color
    }

    static func info(for mission: String) -> MissionInfo {
        switch mission {
        case "Picture of Sky":
            return MissionInfo(
                title: "Why a photo of the sky wakes you up",
                tagline: "Daylight is the master switch.",
                body: "Stepping outside floods your eyes with natural light, which shuts off melatonin and tells your brain the day has begun. Nothing wakes you faster than morning light.",
                icon: "sun.max.fill",
                tint: Color(hex: "F5A623")
            )
        case "Make Your Bed":
            return MissionInfo(
                title: "Why making your bed wakes you up",
                tagline: "Win the first task of the day.",
                body: "Making your bed the moment you're up gives you an instant win and momentum — and it removes the temptation to crawl back under the covers.",
                icon: "bed.double.fill",
                tint: Color(hex: "6C5CE7")
            )
        case "Touch Grass":
            return MissionInfo(
                title: "Why touching grass wakes you up",
                tagline: "Fresh air, light, and motion at once.",
                body: "Going outside combines daylight, cool air, and movement — the three fastest ways to clear sleep inertia. By the time you're back in, you're wide awake.",
                icon: "leaf.fill",
                tint: Color(hex: "27AE60")
            )
        case "Solve Math":
            return MissionInfo(
                title: "Why solving math wakes you up",
                tagline: "Force your thinking brain online.",
                body: "When you're groggy, your prefrontal cortex — the focus-and-logic part of your brain — is still offline. Solving a few problems forces it awake, and once it's engaged you can't drift back to sleep.",
                icon: "function",
                tint: Color(hex: "3B82F6")
            )
        default: // Item Search
            return MissionInfo(
                title: "Why doing an item search wakes you up",
                tagline: "Once you're standing, you're up.",
                body: "Searching for an item gets your body moving before your mind has time to negotiate. Motion beats willpower every time.",
                icon: "camera.viewfinder",
                tint: Color(hex: "1A1A1A")
            )
        }
    }
}

struct ViewfinderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerLength: CGFloat = 30

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))

        return path
    }
}

// MARK: - Alarm Repeat Days (Screen 23)

struct Onboarding2AlarmDaysView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: (Set<Int>) -> Void
    let onBack: (() -> Void)?

    @State private var selectedDays: Set<Int> = Set([1, 2, 3, 4, 5]) // Mon-Fri default

    private let days = [
        (0, "Monday"), (1, "Tuesday"), (2, "Wednesday"),
        (3, "Thursday"), (4, "Friday"), (5, "Saturday"), (6, "Sunday")
    ]

    var body: some View {
        Onboarding2Template(
            title: "Which days should your alarm repeat?",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: !selectedDays.isEmpty,
            onNext: { onNext(selectedDays) },
            onBack: onBack
        ) {
            VStack(spacing: 0) {
                Text("Select at least one day")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "888888"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(height: 20)

                VStack(spacing: 0) {
                    ForEach(days, id: \.0) { dayIndex, dayName in
                        Button(action: {
                            if selectedDays.contains(dayIndex) {
                                selectedDays.remove(dayIndex)
                            } else {
                                selectedDays.insert(dayIndex)
                            }
                        }) {
                            HStack {
                                Text(dayName)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Spacer()

                                Image(systemName: selectedDays.contains(dayIndex) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 22))
                                    .foregroundColor(selectedDays.contains(dayIndex) ? .black : Color(hex: "CCCCCC"))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(HapticButtonStyle())

                        if dayIndex < 6 {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(14)
            }
        }
    }
}

// MARK: - Choose Alarm Sound (Screen 24)

struct Onboarding2AlarmSoundView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: (String) -> Void
    let onBack: (() -> Void)?

    @State private var selectedSound: String = "Default"
    @ObservedObject private var preview = SoundPreviewPlayer.shared

    private let defaultSounds: [(name: String, icon: String)] = [
        ("Default", "speaker.wave.2.fill"),
    ]

    private let alarmSounds: [(name: String, icon: String)] = [
        ("Annoying", "exclamationmark.triangle.fill"),
        ("Beeping", "alarm.fill"),
        ("Zen", "leaf.fill"),
        ("Nature", "tree.fill"),
        ("Rooster", "bird.fill"),
        ("Kalimba", "music.note"),
        ("Guitar", "guitars.fill"),
        ("Jazz", "music.quarternote.3"),
        ("Lofi Piano", "pianokeys"),
        ("Melodic", "music.note.list"),
        ("Loud Bell", "bell.fill"),
        ("Buzzer", "speaker.wave.3.fill"),
        ("Loud Impact", "bolt.fill"),
        ("Fighter Jet", "airplane"),
        ("Navy", "megaphone.fill"),
        ("Raid", "dot.radiowaves.left.and.right"),
    ]

    var body: some View {
        Onboarding2Template(
            title: "Choose your alarm sound",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: true,
            onNext: { onNext(selectedSound) },
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text("You can change this later")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "888888"))

                Spacer().frame(height: 16)

                // Default
                ForEach(defaultSounds, id: \.name) { sound in
                    soundRow(sound: sound)
                }

                // Alarm sounds section
                Text("ALARM SOUNDS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "999999"))
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                ForEach(alarmSounds, id: \.name) { sound in
                    soundRow(sound: sound)
                }
            }
        }
        .onDisappear { preview.stop() }
    }

    private func soundRow(sound: (name: String, icon: String)) -> some View {
        Button(action: { selectedSound = sound.name }) {
            HStack(spacing: 12) {
                Image(systemName: sound.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "666666"))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: "F0F0F0"))
                    .clipShape(Circle())

                Text(sound.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Spacer()

                // Preview play / stop (only for sounds with a bundled file)
                if SoundPreviewPlayer.canPreview(sound.name) {
                    Button(action: { preview.toggle(sound.name) }) {
                        Image(systemName: preview.playingSound == sound.name ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(preview.playingSound == sound.name ? Color(hex: "6C5CE7") : Color(hex: "CCCCCC"))
                    }
                    .buttonStyle(HapticButtonStyle())
                }

                if selectedSound == sound.name {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "34C759"))
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(12)
        }
        .buttonStyle(HapticButtonStyle())
        .padding(.bottom, 6)
    }
}

// MARK: - Get Out of Bed 5x Faster (Screen 26)

struct Onboarding2FasterView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        Onboarding2Template(
            title: "Get out of bed 5x faster with BeYou vs on your own",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: true,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // Comparison card
                HStack(spacing: 16) {
                    // Without BeYou
                    VStack(spacing: 12) {
                        Text("Without BeYou")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A1A"))

                        Spacer()

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "E8E8E8"))
                            .frame(height: 40)
                            .overlay(
                                Text("20%")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "999999"))
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)

                    // With BeYou
                    VStack(spacing: 12) {
                        Text("With BeYou")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A1A"))

                        Spacer()

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .frame(height: 140)
                            .overlay(
                                Text("5x")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                }
                .padding(20)
                .background(Color(hex: "F0F0F0"))
                .cornerRadius(20)
            }
        }
    }
}

// MARK: - Notifications Permission (Screen 27)

struct Onboarding2NotificationsView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "E8E8E8"))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "1A1A1A"))
                            .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 20) {
                Text("Reach your goals with notifications")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                // Fake notification prompt
                VStack(spacing: 0) {
                    Text("BeYou would like to send you notifications")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .padding(.vertical, 16)

                    Divider()

                    HStack(spacing: 0) {
                        Button(action: {
                            requestNotifications()
                            onNext()
                        }) {
                            Text("Don't Allow")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "666666"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }

                        Divider().frame(height: 44)

                        Button(action: {
                            requestNotifications()
                            onNext()
                        }) {
                            Text("Allow")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.black)
                        }
                    }
                }
                .background(Color(hex: "EEEEEE"))
                .cornerRadius(14)
                .padding(.horizontal, 40)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .background(Color(hex: "F8F8F8"))
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
}

// MARK: - Sign Commitment (Screen 28)

struct Onboarding2CommitmentView: View {
    let currentStep: Int
    let totalSteps: Int
    let alarmTime: String
    let onNext: () -> Void
    let onBack: (() -> Void)?

    @State private var lines: [Line] = []
    @State private var currentLine: Line = Line()
    @State private var hasSigned = false

    struct Line: Identifiable {
        var id = UUID()
        var points: [CGPoint] = []
    }

    private var todayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        Onboarding2Template(
            title: "Sign your commitment",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: hasSigned,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 12) {
                (
                    Text("Promise yourself that you will wake up tomorrow at ")
                        .foregroundColor(Color(hex: "1A1A1A"))
                    +
                    Text(alarmTime)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "1A1A1A"))
                    +
                    Text(", when your alarm goes off.")
                        .foregroundColor(Color(hex: "1A1A1A"))
                )
                .font(.system(size: 16))

                Spacer().frame(height: 20)

                Text("Sign to make it official")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "888888"))
                    .frame(maxWidth: .infinity, alignment: .center)

                // Signature canvas
                ZStack(alignment: .topTrailing) {
                    Canvas { context, size in
                        for line in lines {
                            var path = Path()
                            if let firstPoint = line.points.first {
                                path.move(to: firstPoint)
                                for point in line.points.dropFirst() {
                                    path.addLine(to: point)
                                }
                            }
                            context.stroke(path, with: .color(.black), lineWidth: 2.5)
                        }

                        var currentPath = Path()
                        if let firstPoint = currentLine.points.first {
                            currentPath.move(to: firstPoint)
                            for point in currentLine.points.dropFirst() {
                                currentPath.addLine(to: point)
                            }
                        }
                        context.stroke(currentPath, with: .color(.black), lineWidth: 2.5)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                currentLine.points.append(value.location)
                                hasSigned = true
                            }
                            .onEnded { _ in
                                lines.append(currentLine)
                                currentLine = Line()
                            }
                    )

                    // Clear button
                    Button(action: {
                        lines.removeAll()
                        currentLine = Line()
                        hasSigned = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "CCCCCC"))
                    }
                    .padding(12)
                }
                .frame(height: 180)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "E8E8E8"), lineWidth: 1)
                )

                Text("Signed on \(todayFormatted)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "999999"))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Setting Everything Up (Screen 29)

struct Onboarding2LoadingView: View {
    let alarmTime: String
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var statusText: String = "Setting alarm..."

    private let steps = [
        (0.25, "Setting alarm for"),
        (0.50, "Preparing your wake-up challenge..."),
        (0.75, "Configuring your alarm sound..."),
        (1.0, "Almost done..."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("We're setting everything up for you")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .multilineTextAlignment(.center)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "E8E8E8"))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black)
                            .frame(width: geo.size.width * progress, height: 8)
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)

                Text(statusText)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "888888"))
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .background(Color(hex: "F8F8F8"))
        .onAppear {
            animateProgress()
        }
    }

    private func animateProgress() {
        for (index, step) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.8) {
                withAnimation {
                    progress = step.0
                    statusText = step.0 == 0.25 ? "\(step.1) \(alarmTime)" : step.1
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(steps.count) * 0.8 + 0.5) {
            onComplete()
        }
    }
}

// MARK: - Tomorrow You Will Wake Up At (Screen 30)

struct Onboarding2ConfirmationView: View {
    let currentStep: Int
    let totalSteps: Int
    let alarmTime: String
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        Onboarding2Template(
            title: "",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: true,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text("Tomorrow, you will wake up at")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "888888"))

                Text(alarmTime)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                // Flow icons
                HStack(spacing: 16) {
                    flowIcon(systemName: "alarm.fill", label: "Alarm rings")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "CCCCCC"))
                    flowIcon(systemName: "camera.viewfinder", label: "Mission")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "CCCCCC"))
                    flowIcon(systemName: "sun.max.fill", label: "Alarm off")
                }

                Text("No snoozing. No backup alarms.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "888888"))

                // Wake-up streak card
                VStack(spacing: 10) {
                    Text("Your wake-up streak")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Text("Complete your mission on these days to build your streak")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "999999"))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                            Text(day)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "6C5CE7"))
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "6C5CE7").opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
            }
        }
    }

    private func flowIcon(systemName: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black)
                .clipShape(Circle())

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "888888"))
        }
    }
}
