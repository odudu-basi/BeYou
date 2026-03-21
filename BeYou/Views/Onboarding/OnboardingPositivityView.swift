import SwiftUI

@available(iOS 16.0, *)
struct OnboardingPositivityView: View {
    @EnvironmentObject var appState: AppState
    @State private var count: Int = 10
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @State private var showStartPicker = false
    @State private var showEndPicker = false
    @State private var isRequestingPermission = false
    @State private var permissionDenied = false

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private var userName: String {
        appState.onboardingData.name ?? "there"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func requestNotificationPermission() {
        isRequestingPermission = true

        Task {
            let granted = await NotificationManager.shared.requestAuthorization()

            await MainActor.run {
                isRequestingPermission = false

                if granted {
                    // Permission granted - save settings and schedule affirmation notifications
                    appState.onboardingData.affirmationCount = count
                    appState.onboardingData.notifyStartTime = startTime
                    appState.onboardingData.notifyEndTime = endTime

                    NotificationManager.shared.scheduleAffirmationNotifications(
                        count: count,
                        startTime: startTime,
                        endTime: endTime,
                        categories: appState.onboardingData.categories,
                        goals: appState.onboardingData.goals,
                        belief: appState.onboardingData.religion ?? "general",
                        name: appState.onboardingData.name ?? ""
                    )

                    onNext()
                } else {
                    // Permission denied - show "Later" button
                    permissionDenied = true
                }
            }
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Get positivity throughout the day")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                                .lineSpacing(8)

                            Text("Reading affirmations regularly\nwill help you reach your goals")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))
                                .lineSpacing(7)
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 32)

                        // Notification Preview
                        HStack(spacing: 14) {
                            Image("be-you-icon")
                                .resizable()
                                .frame(width: 44, height: 44)
                                .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Be You")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "1A1A1A"))

                                    Spacer()

                                    Text("Now")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "999999"))
                                }

                                Text("\(userName), you are capable of achieving anything you set your mind to. Keep going.")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "666666"))
                                    .lineSpacing(6)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
                        )
                        .padding(.bottom, 32)

                        // Settings
                        VStack(spacing: 0) {
                            // How many
                            HStack {
                                Text("How many")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Spacer()

                                HStack(spacing: 16) {
                                    Button(action: { count = max(1, count - 1) }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: "F0F0F0"))
                                                .frame(width: 36, height: 36)

                                            Text("-")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(Color(hex: "1A1A1A"))
                                        }
                                    }

                                    Text("\(count)x")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(Color(hex: "1A1A1A"))
                                        .frame(minWidth: 36)

                                    Button(action: { count = min(20, count + 1) }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: "F0F0F0"))
                                                .frame(width: 36, height: 36)

                                            Text("+")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(Color(hex: "1A1A1A"))
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 18)

                            Rectangle()
                                .fill(Color(hex: "F0F0F0"))
                                .frame(height: 1)

                            // Start at
                            Button(action: { showStartPicker = true }) {
                                HStack {
                                    Text("Start at")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "1A1A1A"))

                                    Spacer()

                                    Text(formatTime(startTime))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "1A1A1A"))
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                            }

                            Rectangle()
                                .fill(Color(hex: "F0F0F0"))
                                .frame(height: 1)

                            // End at
                            Button(action: { showEndPicker = true }) {
                                HStack {
                                    Text("End at")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "1A1A1A"))

                                    Spacer()

                                    Text(formatTime(endTime))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "1A1A1A"))
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }

                // Bottom buttons
                VStack(spacing: 12) {
                    // Primary button
                    Button(action: requestNotificationPermission) {
                        HStack {
                            if isRequestingPermission {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Allow and Save")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "1A1A1A"))
                        .cornerRadius(16)
                    }
                    .disabled(isRequestingPermission)

                    // Later button (only show if permission was denied)
                    if permissionDenied {
                        Button(action: {
                            // Skip notification setup and continue
                            appState.onboardingData.affirmationCount = count
                            appState.onboardingData.notifyStartTime = startTime
                            appState.onboardingData.notifyEndTime = endTime
                            onNext()
                        }) {
                            Text("Maybe Later")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color(hex: "666666"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(hex: "F0F0F0"))
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 12)
            }
        }
        .sheet(isPresented: $showStartPicker) {
            TimePickerSheet(selectedTime: $startTime, title: "Start Time", isPresented: $showStartPicker)
        }
        .sheet(isPresented: $showEndPicker) {
            TimePickerSheet(selectedTime: $endTime, title: "End Time", isPresented: $showEndPicker)
        }
    }
}

// Time Picker Sheet Component
struct TimePickerSheet: View {
    @Binding var selectedTime: Date
    let title: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "999999"))

                Spacer()

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "1A1A1A"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(Color(hex: "F0F0F0"))
                    .frame(height: 1),
                alignment: .bottom
            )

            // Time Picker
            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.bottom, 34)
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
    }
}
