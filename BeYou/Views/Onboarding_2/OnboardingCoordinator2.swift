import SwiftUI
import SuperwallKit

struct OnboardingCoordinator2: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep: Int = 0
    @State private var idealWakeTimeFormatted: String = "6:00 AM"
    @AppStorage("alarmHour") private var alarmHour: Int = 6
    @AppStorage("alarmMinute") private var alarmMinute: Int = 0

    @AppStorage("alarmSoundName") private var alarmSoundName: String = "Default"
    @AppStorage("alarmMissionName") private var alarmMissionName: String = "Item Search"
    @AppStorage("alarmDays") private var alarmDaysData: Data = Data()
    @AppStorage("alarmItems") private var alarmItemsData: Data = Data()

    let totalSteps: Int = 32

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    /// Turns the user's onboarding choices (time, days, sound, mission, items) into their
    /// first real alarm and schedules it. Skips if an alarm already exists.
    private func createFirstAlarmFromOnboarding() {
        guard AlarmScheduler.loadAlarms().isEmpty else { return }

        // The onboarding days picker uses 0=Mon…6=Sun — same as AlarmItem.repeatDays.
        let days = (try? JSONDecoder().decode(Set<Int>.self, from: alarmDaysData)) ?? Set(0...4)
        let items = (try? JSONDecoder().decode([String].self, from: alarmItemsData)) ?? []

        let alarm = AlarmItem(
            name: "Alarm",
            hour: alarmHour,
            minute: alarmMinute,
            isScheduled: !days.isEmpty,
            repeatDays: days,
            mission: alarmMissionName,
            selectedObjects: alarmMissionName == "Item Search"
                ? (items.isEmpty ? AlarmItem.defaultObjects : items)
                : nil,
            sound: alarmSoundName
        )

        AlarmScheduler.saveAlarms([alarm])
        AlarmScheduler.sync(alarm)
        AnalyticsManager.shared.trackAlarmCreated(alarm)
    }

    var body: some View {
        ZStack {
            switch currentStep {

            // MARK: 0 - Welcome
            case 0:
                Onboarding2WelcomeView(
                    onGetStarted: { withAnimation { currentStep = 100 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 100 - Name (first step after welcome)
            case 100:
                Onboarding2NameView(
                    initialName: appState.onboardingData.name ?? "",
                    currentStep: 1,
                    totalSteps: totalSteps,
                    onNext: { enteredName in
                        appState.onboardingData.name = enteredName
                        SharedDataManager.shared.saveOnboardingData(appState.onboardingData)
                        withAnimation { currentStep = 1 }
                    },
                    onBack: { withAnimation { currentStep = 0 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 1 - Gender
            case 1:
                Onboarding2QuestionView(
                    title: "What is your gender?",
                    options: ["Male", "Female", "Prefer not to say"],
                    currentStep: 1,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.gender = selected
                        withAnimation { currentStep = 2 }
                    },
                    onBack: { withAnimation { currentStep = 100 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 2 - Morning person
            case 2:
                Onboarding2QuestionView(
                    title: "Do you consider yourself a morning person?",
                    options: ["Yes", "No"],
                    currentStep: 2,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.morningPerson = selected
                        withAnimation { currentStep = 3 }
                    },
                    onBack: { withAnimation { currentStep = 1 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 3 - Referral
            case 3:
                Onboarding2ReferralView(
                    currentStep: 3,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.referralSource = selected
                        withAnimation { currentStep = 4 }
                    },
                    onBack: { withAnimation { currentStep = 2 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 4 - Biggest obstacle
            case 4:
                Onboarding2QuestionView(
                    title: "What is your biggest obstacle to getting out of bed?",
                    options: [
                        "I scroll on my phone",
                        "I hit snooze repeatedly",
                        "I sleep through my alarms",
                        "None of the above"
                    ],
                    currentStep: 4,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.biggestObstacle = selected
                        withAnimation { currentStep = 5 }
                    },
                    onBack: { withAnimation { currentStep = 3 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 5 - Snooze prevention graph
            case 5:
                Onboarding2SnoozePreventionView(
                    currentStep: 5,
                    totalSteps: totalSteps,
                    onNext: { withAnimation { currentStep = 6 } },
                    onBack: { withAnimation { currentStep = 4 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 6 - How many alarms
            case 6:
                Onboarding2QuestionView(
                    title: "How many alarms do you usually set?",
                    options: ["Just one", "2 or 3", "4 or more"],
                    currentStep: 6,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.alarmCount = selected
                        withAnimation { currentStep = 7 }
                    },
                    onBack: { withAnimation { currentStep = 5 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 7 - Trust first alarm
            case 7:
                Onboarding2QuestionView(
                    title: "Do you trust yourself to wake up after the first alarm?",
                    options: ["Yes, always", "Sometimes, it's a gamble", "No, never"],
                    currentStep: 7,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.trustFirstAlarm = selected
                        withAnimation { currentStep = 8 }
                    },
                    onBack: { withAnimation { currentStep = 6 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 8 - Turn off alarm
            case 8:
                Onboarding2QuestionView(
                    title: "Do you ever turn off your alarm and go back to sleep?",
                    options: [
                        "Yes, it happens often",
                        "Sometimes",
                        "No, but I worry I might",
                        "No, never"
                    ],
                    currentStep: 8,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.turnOffAlarm = selected
                        withAnimation { currentStep = 9 }
                    },
                    onBack: { withAnimation { currentStep = 7 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 9 - Immediate thought
            case 9:
                Onboarding2QuestionView(
                    title: "When the alarm rings, what is your immediate thought?",
                    options: [
                        "I'm up!",
                        "I'll get up after the next alarm",
                        "Just 5 more minutes...",
                        "Why did I set this?"
                    ],
                    currentStep: 9,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.alarmThought = selected
                        withAnimation { currentStep = 10 }
                    },
                    onBack: { withAnimation { currentStep = 8 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 10 - Negotiate to stay in bed
            case 10:
                Onboarding2QuestionView(
                    title: "Do you negotiate with yourself to stay in bed?",
                    options: ["Yes, I make deals with myself", "No, I get right up"],
                    currentStep: 10,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.negotiateStayInBed = selected
                        withAnimation { currentStep = 11 }
                    },
                    onBack: { withAnimation { currentStep = 9 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 11 - Not a discipline problem
            case 11:
                Onboarding2DisciplineView(
                    currentStep: 11,
                    totalSteps: totalSteps,
                    onNext: { withAnimation { currentStep = 12 } },
                    onBack: { withAnimation { currentStep = 10 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 12 - What time do you usually get out of bed
            case 12:
                Onboarding2TimePickerView(
                    title: "What time do you usually get out of bed?",
                    subtitle: "Be honest - we won't judge",
                    currentStep: 12,
                    totalSteps: totalSteps,
                    defaultHour: 8,
                    defaultMinute: 0,
                    onNext: { date in
                        appState.onboardingData.usualWakeTime = formatTime(date)
                        withAnimation { currentStep = 13 }
                    },
                    onBack: { withAnimation { currentStep = 11 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 13 - What time would you like to get out of bed
            case 13:
                Onboarding2TimePickerView(
                    title: "What time would you like to get out of bed?",
                    subtitle: "The time you wish you could wake up every day",
                    currentStep: 13,
                    totalSteps: totalSteps,
                    defaultHour: 6,
                    defaultMinute: 30,
                    onNext: { date in
                        let formatted = formatTime(date)
                        appState.onboardingData.idealWakeTime = formatted
                        idealWakeTimeFormatted = formatted
                        let calendar = Calendar.current
                        alarmHour = calendar.component(.hour, from: date)
                        alarmMinute = calendar.component(.minute, from: date)
                        withAnimation { currentStep = 14 }
                    },
                    onBack: { withAnimation { currentStep = 12 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 14 - Realistic target
            case 14:
                Onboarding2RealisticTargetView(
                    currentStep: 14,
                    totalSteps: totalSteps,
                    selectedTime: idealWakeTimeFormatted,
                    onNext: { withAnimation { currentStep = 15 } },
                    onBack: { withAnimation { currentStep = 13 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 15 - How do you feel after waking
            case 15:
                Onboarding2QuestionView(
                    title: "How do you feel immediately after waking up?",
                    options: [
                        "Ready to go",
                        "Still sleepy",
                        "Anxious or stressed",
                        "None of the above"
                    ],
                    currentStep: 15,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.feelAfterWaking = selected
                        withAnimation { currentStep = 16 }
                    },
                    onBack: { withAnimation { currentStep = 14 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 16 - How long to feel fully awake
            case 16:
                Onboarding2QuestionView(
                    title: "How long does it usually take you to feel fully awake?",
                    options: ["Instantly", "10-15 minutes", "30 minutes or more"],
                    currentStep: 16,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.timeToFeelAwake = selected
                        withAnimation { currentStep = 17 }
                    },
                    onBack: { withAnimation { currentStep = 15 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 17 - Clear brain fog
            case 17:
                Onboarding2QuestionView(
                    title: "What do you currently rely on to clear that brain fog?",
                    options: [
                        "Coffee or caffeine",
                        "Scrolling social media",
                        "Showering",
                        "Sheer willpower",
                        "Something else"
                    ],
                    currentStep: 17,
                    totalSteps: totalSteps,
                    onNext: { selected in
                        appState.onboardingData.clearBrainFog = selected
                        withAnimation { currentStep = 18 }
                    },
                    onBack: { withAnimation { currentStep = 16 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 18 - Wake the body to wake the mind
            case 18:
                Onboarding2WakeBodyView(
                    currentStep: 18,
                    totalSteps: totalSteps,
                    onNext: { withAnimation { currentStep = 19 } },
                    onBack: { withAnimation { currentStep = 17 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 19 - Set the alarm
            case 19:
                Onboarding2TimePickerView(
                    title: "You set a goal. Now set the alarm.",
                    subtitle: "Earlier, you identified \(idealWakeTimeFormatted) as your ideal wake up time. Let's set your first alarm for this time.",
                    currentStep: 19,
                    totalSteps: totalSteps,
                    dynamicButtonText: true,
                    defaultHour: alarmHour,
                    defaultMinute: alarmMinute,
                    onNext: { date in
                        let calendar = Calendar.current
                        alarmHour = calendar.component(.hour, from: date)
                        alarmMinute = calendar.component(.minute, from: date)
                        idealWakeTimeFormatted = formatTime(date)
                        withAnimation { currentStep = 20 }
                    },
                    onBack: { withAnimation { currentStep = 18 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 20 - Wake-up challenge picker
            case 20:
                Onboarding2ChallengePickerView(
                    currentStep: 20,
                    totalSteps: totalSteps,
                    onNext: { challenge, items in
                        alarmMissionName = challenge
                        if let encoded = try? JSONEncoder().encode(items) {
                            alarmItemsData = encoded
                        }
                        withAnimation { currentStep = 21 }
                    },
                    onBack: { withAnimation { currentStep = 19 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 21 - Why this mission wakes you up (per-mission)
            case 21:
                Onboarding2MissionInfoView(
                    missionName: alarmMissionName,
                    currentStep: 21,
                    totalSteps: totalSteps,
                    onNext: { withAnimation { currentStep = 22 } },
                    onBack: { withAnimation { currentStep = 20 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 22 - Alarm repeat days
            case 22:
                Onboarding2AlarmDaysView(
                    currentStep: 22,
                    totalSteps: totalSteps,
                    onNext: { days in
                        if let encoded = try? JSONEncoder().encode(days) {
                            alarmDaysData = encoded
                        }
                        withAnimation { currentStep = 23 }
                    },
                    onBack: { withAnimation { currentStep = 21 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 23 - Choose alarm sound
            case 23:
                Onboarding2AlarmSoundView(
                    currentStep: 23,
                    totalSteps: totalSteps,
                    onNext: { sound in
                        alarmSoundName = sound
                        withAnimation { currentStep = 24 }
                    },
                    onBack: { withAnimation { currentStep = 22 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 24 - Give us a rating (App Store review prompt)
            case 24:
                Onboarding2RatingView(
                    currentStep: 24,
                    totalSteps: totalSteps,
                    onNext: { withAnimation { currentStep = 25 } },
                    onBack: { withAnimation { currentStep = 23 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 25 - Get out of bed 5x faster
            case 25:
                Onboarding2FasterView(
                    currentStep: 25,
                    totalSteps: totalSteps,
                    onNext: { withAnimation { currentStep = 26 } },
                    onBack: { withAnimation { currentStep = 24 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 26 - Notifications
            case 26:
                Onboarding2NotificationsView(
                    currentStep: 26,
                    totalSteps: totalSteps,
                    onNext: { withAnimation { currentStep = 27 } },
                    onBack: { withAnimation { currentStep = 25 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 27 - Alarm Access
            case 27:
                if #available(iOS 26.1, *) {
                    Onboarding2AlarmAccessView(
                        currentStep: 27,
                        totalSteps: totalSteps,
                        onNext: { withAnimation { currentStep = 28 } },
                        onBack: { withAnimation { currentStep = 26 } }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                } else {
                    // AlarmKit is iOS 26+; on older versions skip the alarm-access screen.
                    Color.clear.onAppear { withAnimation { currentStep = 28 } }
                }

            // MARK: 28 - Sign commitment
            case 28:
                Onboarding2CommitmentView(
                    currentStep: 28,
                    totalSteps: totalSteps,
                    alarmTime: idealWakeTimeFormatted,
                    onNext: {
                        // Persist all onboarding answers to Supabase BEFORE the paywall, so users
                        // who don't purchase are still captured (previously this only ran at the
                        // final confirmation step, after the paywall — so non-payers were lost).
                        UserProfileService.shared.saveOnboardingProfile(appState.onboardingData)
                        withAnimation { currentStep = 29 }
                    },
                    onBack: { withAnimation { currentStep = 27 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 29 - Paywall (Superwall)
            case 29:
                Onboarding2PaywallView(
                    onPurchased: { withAnimation { currentStep = 30 } },
                    onSkipped: { withAnimation { currentStep = 30 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 30 - Setting everything up
            case 30:
                Onboarding2LoadingView(
                    alarmTime: idealWakeTimeFormatted,
                    onComplete: {
                        createFirstAlarmFromOnboarding()
                        withAnimation { currentStep = 31 }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            // MARK: 31 - Tomorrow you will wake up at
            case 31:
                Onboarding2ConfirmationView(
                    currentStep: 31,
                    totalSteps: totalSteps,
                    alarmTime: idealWakeTimeFormatted,
                    onNext: {
                        SharedDataManager.shared.saveHasCompletedOnboarding(true)
                        SharedDataManager.shared.saveHasCompletedSetup(true)
                        // TikTok conversion event: user finished onboarding (a "registration").
                        TikTokManager.shared.trackOnboardingComplete()
                        // Onboarding answers are now persisted to Supabase earlier (step 28, before
                        // the paywall) so non-payers are captured too. The later subscription sync
                        // merges payment status onto that same device_id row.
                        appState.navigateTo(.main)
                    },
                    onBack: { withAnimation { currentStep = 30 } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            default:
                Text("Onboarding complete!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
}
