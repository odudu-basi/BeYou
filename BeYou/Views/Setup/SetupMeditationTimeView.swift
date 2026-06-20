import SwiftUI

@available(iOS 16.0, *)
struct SetupMeditationTimeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    let onNext: () -> Void
    let onSkip: () -> Void
    let onBack: (() -> Void)?

    @State private var name: String = "Morning Meditation"
    @State private var selectedDate = Date()
    @State private var selectedDays: Set<Int> = Set(1...7)

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayValues = [1, 2, 3, 4, 5, 6, 7]

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button
                HStack {
                    if let onBack = onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "1A1A1A"))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Icon
                        Image(systemName: "figure.mind.and.body")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: "6C5CE7"))
                            .padding(.top, 20)

                        // Title
                        VStack(spacing: 10) {
                            Text("When would you like\nto meditate?")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .multilineTextAlignment(.center)

                            Text("Set a daily time to pause, breathe, and speak positivity to yourself.")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 20)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "666666"))
                            TextField("e.g. Morning Meditation", text: $name)
                                .font(.system(size: 16))
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E8E8E8"), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 24)

                        // Time picker
                        DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)

                        // Day picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Repeat")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "666666"))

                            HStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { index in
                                    let day = dayValues[index]
                                    Button(action: {
                                        if selectedDays.contains(day) {
                                            if selectedDays.count > 1 {
                                                selectedDays.remove(day)
                                            }
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    }) {
                                        Text(dayLabels[index])
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(selectedDays.contains(day) ? .white : Color(hex: "666666"))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                selectedDays.contains(day)
                                                    ? Color(hex: "1A1A1A")
                                                    : Color(hex: "F0F0F0")
                                            )
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
                }

                // Buttons
                VStack(spacing: 12) {
                    Button(action: saveMeditationTime) {
                        Text("Add Meditation Time")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "1A1A1A"))
                            .cornerRadius(16)
                    }

                    Button(action: onSkip) {
                        Text("Skip for now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "999999"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }

    private func saveMeditationTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)

        let time = MeditationTime(
            name: name.isEmpty ? "Meditation" : name,
            hour: hour,
            minute: minute,
            days: selectedDays
        )

        // Save
        SharedDataManager.shared.saveMeditationTimes([time])
        if let data = try? JSONEncoder().encode([time]) {
            UserDefaults.standard.set(data, forKey: "meditationTimesData")
        }

        // Schedule notifications and DeviceActivity
        NotificationManager.shared.scheduleMeditationNotifications(times: [time])
        screenTimeManager.registerMeditationSchedules(times: [time])

        AnalyticsManager.shared.track("Setup Meditation Time Added", properties: [
            "name": name,
            "hour": hour,
            "minute": minute
        ])

        onNext()
    }
}
