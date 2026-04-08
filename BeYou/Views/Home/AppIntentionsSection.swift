import SwiftUI

@available(iOS 16.0, *)
struct AppIntentionsSection: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var showAddModal = false
    @State private var editingAppName: String?
    @State private var showDeleteConfirmation: String?
    @State private var expandedAppName: String?

    private var appIntentions: [(String, IndividualAppIntention)] {
        appState.onboardingData.appIntention.perAppIntentions
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text("App Intentions")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "999999"))
                }

                Spacer()

                // Add button (blue circle +)
                Button {
                    showAddModal = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "3B82F6"))
                        .clipShape(Circle())
                }
            }

            // Content
            if appIntentions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(appIntentions, id: \.0) { appName, intention in
                        AppIntentionCard(
                            appTokenData: intention.appTokenData,
                            timesPerDay: intention.timesPerDay,
                            minutesPerSession: intention.minutesPerSession,
                            currentOpens: appState.getAppBreakthroughs(appName),
                            isExpanded: expandedAppName == appName,
                            onTap: {
                                withAnimation {
                                    expandedAppName = expandedAppName == appName ? nil : appName
                                }
                            },
                            onEdit: {
                                expandedAppName = nil
                                editingAppName = appName
                            },
                            onDelete: {
                                expandedAppName = nil
                                showDeleteConfirmation = appName
                            }
                        )
                    }

                    // Add App Intention dashed button
                    addButton
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showAddModal) {
            AddAppIntentionModal { appName, intention in
                addOrUpdateIntention(appName: appName, intention: intention)
            }
        }
        .sheet(item: Binding(
            get: { editingAppName.map { AppNameWrapper(name: $0) } },
            set: { editingAppName = $0?.name }
        )) { wrapper in
            AddAppIntentionModal(existingAppName: wrapper.name) { appName, intention in
                addOrUpdateIntention(appName: appName, intention: intention)
            }
        }
        .confirmationDialog(
            "Delete \(showDeleteConfirmation ?? "App") Intention?",
            isPresented: Binding(
                get: { showDeleteConfirmation != nil },
                set: { if !$0 { showDeleteConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let appName = showDeleteConfirmation {
                    deleteIntention(appName: appName)
                }
            }
            Button("Cancel", role: .cancel) {
                showDeleteConfirmation = nil
            }
        } message: {
            Text("This will remove the intention for \(showDeleteConfirmation ?? "this app").")
        }
    }

    private var emptyState: some View {
        Button {
            showAddModal = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))

                Text("Add App Intention")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(Color(hex: "3B82F6"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(hex: "E0E0E0"), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
    }

    private var addButton: some View {
        Button {
            showAddModal = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))

                Text("Add App Intention")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color(hex: "999999"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(hex: "E0E0E0"), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
    }

    private func addOrUpdateIntention(appName: String, intention: IndividualAppIntention) {
        appState.onboardingData.appIntention.perAppIntentions[appName] = intention

        if !appState.onboardingData.selectedAppsForBlocking.contains(appName) {
            appState.onboardingData.selectedAppsForBlocking.append(appName)
        }

        if appState.appUsageStats.breakthroughsByApp[appName] == nil {
            appState.appUsageStats.breakthroughsByApp[appName] = 0
            appState.appUsageStats.currentStreakByApp[appName] = 0
        }

        // Save to shared storage (both individual fields AND full OnboardingData
        // so loadPersistedData() picks up the changes on next app launch)
        SharedDataManager.shared.saveAppIntention(appState.onboardingData.appIntention)
        SharedDataManager.shared.saveOnboardingData(appState.onboardingData)
        SharedDataManager.shared.saveUsageStats(appState.appUsageStats)

        // Cancel streak warning since user now has an intention
        NotificationManager.shared.cancelStreakWarningNotification()

        // Track analytics
        AnalyticsManager.shared.trackAppIntentionCreated(
            appName: appName,
            timesPerDay: intention.timesPerDay,
            minutesPerSession: intention.minutesPerSession
        )
    }

    private func deleteIntention(appName: String) {
        appState.onboardingData.appIntention.perAppIntentions.removeValue(forKey: appName)

        if let index = appState.onboardingData.selectedAppsForBlocking.firstIndex(of: appName) {
            appState.onboardingData.selectedAppsForBlocking.remove(at: index)
        }

        appState.appUsageStats.breakthroughsByApp.removeValue(forKey: appName)
        appState.appUsageStats.currentStreakByApp.removeValue(forKey: appName)
        appState.appUsageStats.longestStreakByApp.removeValue(forKey: appName)
        appState.appUsageStats.unlockedApps.remove(appName)
        appState.appUsageStats.unlockExpiryByApp.removeValue(forKey: appName)

        // Save to shared storage (both individual fields AND full OnboardingData)
        SharedDataManager.shared.saveAppIntention(appState.onboardingData.appIntention)
        SharedDataManager.shared.saveOnboardingData(appState.onboardingData)
        SharedDataManager.shared.saveUsageStats(appState.appUsageStats)

        // Track analytics
        AnalyticsManager.shared.trackAppIntentionDeleted(appName: appName)

        // NEW: Remove the app's dedicated store (unblocks the app)
        print("🗑️ APP INTENTION: Removing store for \(appName)")
        screenTimeManager.removeAppStore(forKey: appName)

        showDeleteConfirmation = nil
    }
}

// Helper wrapper for sheet binding
struct AppNameWrapper: Identifiable {
    let id = UUID()
    let name: String
}
