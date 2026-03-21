import SwiftUI
import FamilyControls
import ManagedSettings

struct OnboardingPerAppIntentionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    let currentStep: Int?
    let totalSteps: Int?
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var showAppPicker = false
    @State private var hasSelectedApp = false
    @State private var selectedToken: ApplicationToken?
    @State private var selectedTokenData: Data?
    @State private var timesPerDay: Int = 10
    @State private var minutesPerSession: Int = 5
    @State private var showTimesPicker = false
    @State private var showMinutesPicker = false
    @State private var tempValue: Int = 10
    @State private var showTooManyAppsAlert = false
    @State private var showDuplicateAppAlert = false
    @State private var duplicateAppName: String = ""

    private let timeOptions = Array(1...20)
    private let minuteOptions = [5, 10, 15, 20, 25, 30, 35, 45]

    private var selectedAppCount: Int {
        screenTimeManager.activitySelection.applicationTokens.count +
        screenTimeManager.activitySelection.categoryTokens.count
    }

    var body: some View {
        ZStack {
            Color(hex: "F0F4FA").ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Header
                VStack(spacing: 8) {
                    Text("Set your intention")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Text("Only choose 1 app to begin")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "999999"))
                }
                .padding(.top, 32)
                .padding(.bottom, 40)

                // Intention card
                VStack(spacing: 20) {
                    // Row 1: I'll open [Select app with REAL name and icon]
                    HStack(spacing: 8) {
                        Text("I'll open")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "666666"))

                        Button(action: { showAppPicker = true }) {
                            HStack(spacing: 8) {
                                if let token = selectedToken {
                                    // Show REAL app icon (smaller)
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .frame(width: 24, height: 24)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))

                                    // Show REAL app name (compact)
                                    Label(token)
                                        .labelStyle(.titleOnly)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "1A1A1A"))
                                        .lineLimit(1)
                                        .fixedSize()
                                } else {
                                    Image(systemName: "app.badge.plus")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "5B8DEF"))

                                    Text("Select app")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "999999"))
                                }

                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "5B8DEF"))
                            }
                            .frame(height: 36)
                            .padding(.horizontal, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                            )
                        }

                        Spacer()
                    }

                    // Row 2: no more than [10] times a day
                    HStack(spacing: 8) {
                        Text("no more than")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "666666"))

                        Button(action: {
                            tempValue = timesPerDay
                            showTimesPicker = true
                        }) {
                            HStack(spacing: 4) {
                                Text("\(timesPerDay)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "5B8DEF"))

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "5B8DEF"))
                            }
                        }

                        Text("times a day")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "666666"))

                        Spacer()
                    }

                    // Row 3: for [5 min] each time
                    HStack(spacing: 8) {
                        Text("for")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "666666"))

                        Button(action: {
                            tempValue = minutesPerSession
                            showMinutesPicker = true
                        }) {
                            HStack(spacing: 4) {
                                Text("\(minutesPerSession) min")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "5B8DEF"))

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "5B8DEF"))
                            }
                        }

                        Text("each time")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "666666"))

                        Spacer()
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
                )
                .padding(.horizontal, 20)

                Spacer()

                // Continue button
                Button(action: {
                    saveIntention()
                    onNext()
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(hasSelectedApp ? Color(hex: "1A1A1A") : Color(hex: "CCCCCC"))
                        .cornerRadius(16)
                }
                .disabled(!hasSelectedApp)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $screenTimeManager.activitySelection)
        .onChange(of: screenTimeManager.activitySelection) { newSelection in
            let appCount = newSelection.applicationTokens.count
            let categoryCount = newSelection.categoryTokens.count
            let totalCount = appCount + categoryCount

            if totalCount > 1 {
                // Too many items selected - show warning
                print("⚠️ ONBOARDING: User selected \(totalCount) items (max 1 allowed)")
                showTooManyAppsAlert = true
                hasSelectedApp = false
                selectedToken = nil
                selectedTokenData = nil
                // Clear selection so they can try again
                screenTimeManager.activitySelection = FamilyActivitySelection()
            } else if totalCount == 1 {
                if let firstToken = newSelection.applicationTokens.first {
                    // Check if this app already has an intention
                    let tokenKey = "app_\(firstToken.hashValue)"

                    if let existingIntention = appState.onboardingData.appIntention.perAppIntentions[tokenKey] {
                        // App already has an intention!
                        print("⚠️ ONBOARDING: App already has an intention (key: \(tokenKey))")
                        duplicateAppName = existingIntention.appName
                        showDuplicateAppAlert = true
                        hasSelectedApp = false
                        selectedToken = nil
                        selectedTokenData = nil
                        // Clear selection so they can try again
                        screenTimeManager.activitySelection = FamilyActivitySelection()
                    } else {
                        // App is available - good to go!
                        hasSelectedApp = true
                        selectedToken = firstToken

                        // Encode the token to Data for storing
                        if let encoded = try? JSONEncoder().encode(firstToken) {
                            selectedTokenData = encoded
                            print("📱 ONBOARDING: ✅ App selected and token encoded")
                        }
                    }
                }
            } else {
                // No selection
                hasSelectedApp = false
                selectedToken = nil
                selectedTokenData = nil
            }
        }
        .alert("One App Per Intention", isPresented: $showTooManyAppsAlert) {
            Button("OK") {
                showTooManyAppsAlert = false
            }
        } message: {
            Text("Each intention can only track one app. Please select just one app.\n\nYou can create additional app intentions from the home screen after setup.")
        }
        .alert("App Already Has Intention", isPresented: $showDuplicateAppAlert) {
            Button("OK") {
                showDuplicateAppAlert = false
            }
        } message: {
            Text("This app already has an intention set.\n\nPlease select a different app that doesn't already have an intention.")
        }
        .sheet(isPresented: $showTimesPicker) {
            pickerSheet(title: "Times per day", options: timeOptions, suffix: "times") { value in
                timesPerDay = value
            }
        }
        .sheet(isPresented: $showMinutesPicker) {
            pickerSheet(title: "Minutes per session", options: minuteOptions, suffix: "min") { value in
                minutesPerSession = value
            }
        }
        .onAppear {
            loadExisting()
        }
    }

    // MARK: - Picker Sheet

    private func pickerSheet(title: String, options: [Int], suffix: String, onDone: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    showTimesPicker = false
                    showMinutesPicker = false
                }
                .foregroundColor(Color(hex: "999999"))

                Spacer()

                Text(title)
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Button("Done") {
                    onDone(tempValue)
                    showTimesPicker = false
                    showMinutesPicker = false
                }
                .foregroundColor(Color(hex: "5B8DEF"))
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Picker(title, selection: $tempValue) {
                ForEach(options, id: \.self) { option in
                    Text("\(option) \(suffix)").tag(option)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)
        }
        .presentationDetents([.height(280)])
    }

    // MARK: - Data

    private func loadExisting() {
        timesPerDay = appState.onboardingData.appIntention.timesPerDay
        minutesPerSession = appState.onboardingData.appIntention.minutesPerSession
        hasSelectedApp = selectedAppCount == 1
    }

    private func saveIntention() {
        // Save global defaults
        appState.onboardingData.appIntention.timesPerDay = timesPerDay
        appState.onboardingData.appIntention.minutesPerSession = minutesPerSession

        // Create per-app intention entry for the selected app
        if let token = selectedToken, let tokenData = selectedTokenData {
            // Use token hash as unique key (will be replaced with real name when shield is first shown)
            let tokenKey = "app_\(token.hashValue)"
            print("📱 ONBOARDING: Creating per-app intention with key: \(tokenKey)")

            let intention = IndividualAppIntention(
                appName: tokenKey, // Temporary key, will be updated to real name by shield
                bundleIdentifier: nil,
                appTokenData: tokenData, // Save encoded token for icon/name display
                timesPerDay: timesPerDay,
                minutesPerSession: minutesPerSession
            )

            // Add to per-app intentions dictionary
            appState.onboardingData.appIntention.perAppIntentions[tokenKey] = intention

            // Add to selected apps list if not already there
            if !appState.onboardingData.selectedAppsForBlocking.contains(tokenKey) {
                appState.onboardingData.selectedAppsForBlocking.append(tokenKey)
            }

            // Initialize usage stats for this app
            if appState.appUsageStats.breakthroughsByApp[tokenKey] == nil {
                appState.appUsageStats.breakthroughsByApp[tokenKey] = 0
                appState.appUsageStats.currentStreakByApp[tokenKey] = 0
            }

            print("📱 ONBOARDING: ✅ Per-app intention created successfully!")

            // NEW: Block this specific app independently with its own store
            print("📱 ONBOARDING: Blocking app independently with key: \(tokenKey)")
            screenTimeManager.blockApp(token: token, forKey: tokenKey)
        }

        // Save to shared storage
        SharedDataManager.shared.saveAppIntention(appState.onboardingData.appIntention)
        SharedDataManager.shared.saveUsageStats(appState.appUsageStats)
    }
}
