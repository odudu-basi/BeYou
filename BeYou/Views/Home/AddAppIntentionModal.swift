import SwiftUI
import FamilyControls
import ManagedSettings

@available(iOS 16.0, *)
struct AddAppIntentionModal: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @Environment(\.dismiss) var dismiss

    @State private var appSelection = FamilyActivitySelection()
    @State private var selectedToken: ApplicationToken?
    @State private var selectedTokenData: Data?
    @State private var isPickerPresented = false
    @State private var timesPerDay: Int = 10
    @State private var minutesPerSession: Int = 5
    @State private var showDuplicateAppAlert = false
    @State private var showMultipleAppsAlert = false
    @State private var showCategoryAlert = false

    let existingAppName: String? // For editing existing intentions
    let onSave: (String, IndividualAppIntention) -> Void

    private let timeOptions = Array(5...20)
    private let minuteOptions = [5, 10, 15, 20, 25, 30, 35, 45]

    init(existingAppName: String? = nil, onSave: @escaping (String, IndividualAppIntention) -> Void) {
        self.existingAppName = existingAppName
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: "F8FAFC"), Color(hex: "F1F5F9")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(existingAppName != nil ? "Edit Intention" : "Set your intention")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "1E293B"))

                            Text("Choose an app and set your limits")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "64748B"))
                        }
                        .padding(.top, 24)

                        // Intention Card
                        VStack(spacing: 20) {
                            // App selection
                            if existingAppName == nil {
                                // Select app from iOS picker
                                Button {
                                    // Clear previous selection so picker starts fresh
                                    appSelection = FamilyActivitySelection()
                                    isPickerPresented = true
                                } label: {
                                    HStack(spacing: 12) {
                                        if let token = selectedToken {
                                            // Show REAL app icon
                                            Label(token)
                                                .labelStyle(.iconOnly)
                                                .frame(width: 40, height: 40)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                            // Show REAL app name
                                            Label(token)
                                                .labelStyle(.titleOnly)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "1E293B"))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        } else {
                                            Image(systemName: "plus.app")
                                                .font(.system(size: 20))
                                                .foregroundColor(Color(hex: "94A3B8"))

                                            Text("Select App to Block")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Color(hex: "94A3B8"))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color(hex: "64748B"))
                                    }
                                    .frame(height: 56)
                                    .padding(.horizontal, 16)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "E2E8F0"), lineWidth: 1.5)
                                    )
                                }
                            } else {
                                // Show existing app with real icon/name from token
                                HStack(spacing: 12) {
                                    if let token = selectedToken {
                                        Label(token)
                                            .labelStyle(.iconOnly)
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))

                                        Label(token)
                                            .labelStyle(.titleOnly)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Color(hex: "1E293B"))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    } else {
                                        // Fallback if token not yet loaded
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: "3B82F6").opacity(0.1))
                                                .frame(width: 40, height: 40)

                                            Image(systemName: "app.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color(hex: "3B82F6"))
                                        }

                                        Text("Loading...")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Color(hex: "94A3B8"))
                                    }

                                    Spacer()
                                }
                            }

                            Divider()

                            // Summary
                            VStack(spacing: 12) {
                                HStack {
                                    Text("no more than")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "64748B"))

                                    Spacer()

                                    Text("\(timesPerDay)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Color(hex: "3B82F6"))

                                    Text("times a day")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "64748B"))
                                }

                                HStack {
                                    Text("for")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "64748B"))

                                    Spacer()

                                    Text("\(minutesPerSession)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Color(hex: "10B981"))

                                    Text("min each time")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "64748B"))
                                }
                            }

                            Divider()

                            // Pickers
                            VStack(spacing: 20) {
                                // Times per day
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TIMES PER DAY")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "64748B"))

                                    Picker("Times per day", selection: $timesPerDay) {
                                        ForEach(timeOptions, id: \.self) { time in
                                            Text("\(time) times").tag(time)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 100)
                                }

                                // Minutes per session
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("MINUTES PER SESSION")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "64748B"))

                                    Picker("Minutes per session", selection: $minutesPerSession) {
                                        ForEach(minuteOptions, id: \.self) { minutes in
                                            Text("\(minutes) min").tag(minutes)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 100)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)

                        // Save button
                        Button(action: handleSave) {
                            Text(existingAppName != nil ? "Update Intention" : "Set App Intention")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canSave ? Color(hex: "3B82F6") : Color(hex: "CBD5E1"))
                                .cornerRadius(12)
                        }
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "64748B"))
                }
            }
        }
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: $appSelection
        )
        .onChange(of: appSelection) { newSelection in
            let appCount = newSelection.applicationTokens.count
            let categoryCount = newSelection.categoryTokens.count

            if categoryCount > 0 {
                // User selected a category instead of an individual app
                print("⚠️ MODAL: User selected a category, not an individual app")
                appSelection = FamilyActivitySelection()
                selectedToken = nil
                selectedTokenData = nil
                showCategoryAlert = true
                return
            }

            if appCount > 1 {
                // Too many selected - clear and show warning
                print("⚠️ MODAL: User selected \(appCount) items (max 1)")
                appSelection = FamilyActivitySelection()
                selectedToken = nil
                selectedTokenData = nil
                showMultipleAppsAlert = true
            } else if let firstToken = newSelection.applicationTokens.first {
                // Only check for duplicates when creating NEW intention (not editing)
                if existingAppName == nil {
                    let tokenKey = "app_\(firstToken.hashValue)"

                    // Check if this app already has an intention
                    if appState.onboardingData.appIntention.perAppIntentions[tokenKey] != nil {
                        // App already has an intention!
                        print("⚠️ MODAL: App already has an intention (key: \(tokenKey))")
                        showDuplicateAppAlert = true
                        appSelection = FamilyActivitySelection()
                        selectedToken = nil
                        selectedTokenData = nil
                        return
                    }
                }

                // App is available (or we're editing existing) - good to go!
                selectedToken = firstToken

                // Encode the token to Data
                if let encoded = try? JSONEncoder().encode(firstToken) {
                    selectedTokenData = encoded
                    print("📱 MODAL: ✅ App selected and token encoded")
                }
            } else {
                // No selection
                selectedToken = nil
                selectedTokenData = nil
            }
        }
        .onAppear {
            loadExistingIntention()
        }
        .alert("App Already Has Intention", isPresented: $showDuplicateAppAlert) {
            Button("OK") {
                showDuplicateAppAlert = false
            }
        } message: {
            Text("This app already has an intention set.\n\nPlease select a different app, or edit the existing intention from the home screen.")
        }
        .alert("One App at a Time", isPresented: $showMultipleAppsAlert) {
            Button("Got it") {
                showMultipleAppsAlert = false
            }
        } message: {
            Text("Please select only one app per intention. You can add more intentions for other apps separately.")
        }
        .alert("Select an App, Not a Category", isPresented: $showCategoryAlert) {
            Button("Got it") {
                showCategoryAlert = false
            }
        } message: {
            Text("Please select an individual app, not an entire category. Tap on a specific app to set an intention for it.")
        }
    }

    private var canSave: Bool {
        if existingAppName != nil {
            return true
        }

        return selectedToken != nil && selectedTokenData != nil
    }

    private var finalAppKey: String {
        if let existing = existingAppName {
            return existing
        }

        // Use token hash as unique key for new apps
        if let token = selectedToken {
            return "app_\(token.hashValue)"
        }

        return "unknown"
    }

    private func loadExistingIntention() {
        guard let appName = existingAppName,
              let intention = appState.onboardingData.appIntention.perAppIntentions[appName] else {
            return
        }

        timesPerDay = intention.timesPerDay
        minutesPerSession = intention.minutesPerSession

        // Restore the token so we can display the real app icon/name
        if let tokenData = intention.appTokenData,
           let token = try? JSONDecoder().decode(ApplicationToken.self, from: tokenData) {
            selectedToken = token
            selectedTokenData = tokenData
        }
    }

    private func handleSave() {
        // For edits, preserve the existing token data if we didn't select a new app
        let tokenData: Data?
        if let selected = selectedTokenData {
            tokenData = selected
        } else if let appName = existingAppName,
                  let existing = appState.onboardingData.appIntention.perAppIntentions[appName] {
            tokenData = existing.appTokenData
        } else {
            tokenData = nil
        }

        // Create and save the intention
        let intention = IndividualAppIntention(
            appName: finalAppKey,
            bundleIdentifier: nil,
            appTokenData: tokenData,
            timesPerDay: timesPerDay,
            minutesPerSession: minutesPerSession
        )

        print("📱 MODAL: Saving intention with key: \(finalAppKey)")
        onSave(finalAppKey, intention)

        // If this is a new app (not editing existing), block it independently
        if existingAppName == nil, let token = selectedToken {
            print("📱 MODAL: Blocking app independently with key: \(finalAppKey)")
            screenTimeManager.blockApp(token: token, forKey: finalAppKey)
            print("📱 MODAL: ✅ App blocked independently")
        }

        dismiss()
    }
}
