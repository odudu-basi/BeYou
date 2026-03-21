import SwiftUI

struct OnboardingDisconnectTimeView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTime: DisconnectTime?
    @State private var showTimePicker = false

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    enum DisconnectTime: String, CaseIterable {
        case morning = "Morning"
        case beforeBed = "Before Bed"
        case atWork = "At Work"

        var emoji: String {
            switch self {
            case .morning: return "🌅"
            case .beforeBed: return "🌙"
            case .atWork: return "💼"
            }
        }

        var description: String {
            switch self {
            case .morning: return "Start your day focused"
            case .beforeBed: return "Wind down peacefully"
            case .atWork: return "Stay productive"
            }
        }

        var defaultStartTime: Date {
            let calendar = Calendar.current
            switch self {
            case .morning:
                return calendar.date(from: DateComponents(hour: 6, minute: 0)) ?? Date()
            case .beforeBed:
                return calendar.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
            case .atWork:
                return calendar.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
            }
        }

        var defaultEndTime: Date {
            let calendar = Calendar.current
            switch self {
            case .morning:
                return calendar.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
            case .beforeBed:
                return calendar.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
            case .atWork:
                return calendar.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
            }
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        VStack(spacing: 8) {
                            Text("When do you want to disconnect?")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            Text("Choose the time that works best for you")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "666666"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 16)

                        // Time options
                        VStack(spacing: 16) {
                            ForEach(DisconnectTime.allCases, id: \.self) { time in
                                DisconnectTimeCard(
                                    emoji: time.emoji,
                                    title: time.rawValue,
                                    description: time.description,
                                    isSelected: selectedTime == time
                                ) {
                                    selectedTime = time
                                    showTimePicker = true
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer()
                    }
                }

                // Bottom button
                VStack(spacing: 12) {
                    Button(action: {
                        // Skip to main app
                        appState.navigateTo(.main)
                    }) {
                        Text("I'll do this later")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "666666"))
                    }
                    .padding(.bottom, 8)

                    if let back = onBack {
                        Button(action: back) {
                            Text("Back")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "999999"))
                        }
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .sheet(isPresented: $showTimePicker) {
            if let time = selectedTime {
                DisconnectTimePickerView(
                    disconnectTime: time,
                    onConfirm: { startTime, endTime in
                        // Save the schedule
                        appState.onboardingData.disconnectSchedule.type = time.rawValue
                        appState.onboardingData.disconnectSchedule.startTime = startTime
                        appState.onboardingData.disconnectSchedule.endTime = endTime
                        showTimePicker = false
                        onNext()
                    },
                    onSkip: {
                        showTimePicker = false
                        appState.navigateTo(.main)
                    }
                )
                .environmentObject(appState)
            }
        }
    }
}

struct DisconnectTimeCard: View {
    let emoji: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Emoji circle
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "1A1A1A") : Color(hex: "F0F0F0"))
                        .frame(width: 60, height: 60)

                    Text(emoji)
                        .font(.system(size: 28))
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "666666"))
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "999999"))
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "1A1A1A") : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }
}

struct DisconnectTimePickerView: View {
    let disconnectTime: OnboardingDisconnectTimeView.DisconnectTime
    let onConfirm: (Date, Date) -> Void
    let onSkip: () -> Void

    @State private var startTime: Date
    @State private var endTime: Date

    init(disconnectTime: OnboardingDisconnectTimeView.DisconnectTime,
         onConfirm: @escaping (Date, Date) -> Void,
         onSkip: @escaping () -> Void) {
        self.disconnectTime = disconnectTime
        self.onConfirm = onConfirm
        self.onSkip = onSkip
        _startTime = State(initialValue: disconnectTime.defaultStartTime)
        _endTime = State(initialValue: disconnectTime.defaultEndTime)
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()

                    VStack(spacing: 4) {
                        Text(disconnectTime.emoji)
                            .font(.system(size: 40))

                        Text(disconnectTime.rawValue)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }

                    Spacer()
                }
                .padding(.top, 24)
                .padding(.bottom, 32)

                // Time pickers card
                VStack(spacing: 24) {
                    // Start time
                    VStack(spacing: 12) {
                        Text("Disconnect from")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "666666"))

                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }

                    Divider()
                        .background(Color(hex: "E0E0E0"))

                    // End time
                    VStack(spacing: 12) {
                        Text("Reconnect at")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "666666"))

                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 24)

                Spacer()

                // Bottom buttons
                VStack(spacing: 16) {
                    Button(action: {
                        onConfirm(startTime, endTime)
                    }) {
                        Text("Set Schedule")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "1A1A1A"))
                            .cornerRadius(16)
                    }

                    Button(action: onSkip) {
                        Text("I'll do this later")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "666666"))
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }
}
