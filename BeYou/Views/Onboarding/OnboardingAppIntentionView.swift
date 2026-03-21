import SwiftUI

struct OnboardingAppIntentionView: View {
    @EnvironmentObject var appState: AppState
    @State private var timesPerDay: Int = 10
    @State private var minutesPerSession: Int = 5
    @State private var selectedAppName: String = "Instagram"
    @State private var showTimePicker: Bool = false
    @State private var showMinutesPicker: Bool = false

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private let timeOptions = Array(5...20) // 5-20 times per day
    private let minuteOptions = [5, 10, 15, 20, 25, 30, 35, 45] // Specific duration options

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "E8F0FE"), Color(hex: "F0F4FF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress Bar
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        Text("Set your intention")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)

                        // Intention Card
                        VStack(alignment: .leading, spacing: 20) {
                            // App Selection Row
                            HStack(spacing: 12) {
                                Text("I'll open")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                HStack(spacing: 8) {
                                    // App icon placeholder (you can replace with actual app icon)
                                    Circle()
                                        .fill(Color(hex: "5B51D8"))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(String(selectedAppName.prefix(1)))
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                        )

                                    Text(selectedAppName)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(hex: "1A1A1A"))

                                    Spacer()

                                    Button(action: {
                                        // TODO: Open app picker
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color(hex: "5B51D8"))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(12)
                            }

                            // Times per day row
                            HStack(spacing: 12) {
                                Text("no more than")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Button(action: {
                                    showTimePicker = true
                                }) {
                                    HStack(spacing: 4) {
                                        Text("\(timesPerDay)")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Color(hex: "5B51D8"))
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "5B51D8"))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(8)
                                }

                                Text("times a day")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                            }

                            // Minutes per session row
                            HStack(spacing: 12) {
                                Text("for")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Button(action: {
                                    showMinutesPicker = true
                                }) {
                                    HStack(spacing: 4) {
                                        Text("\(minutesPerSession) min")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Color(hex: "5B51D8"))
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "5B51D8"))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(8)
                                }

                                Text("each time")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 4)
                        )
                        .padding(.horizontal, 24)

                        Spacer()
                    }
                }

                // Bottom buttons
                VStack(spacing: 12) {
                    Button(action: {
                        appState.onboardingData.appIntention.timesPerDay = timesPerDay
                        appState.onboardingData.appIntention.minutesPerSession = minutesPerSession
                        onNext()
                    }) {
                        Text("Set App Intention")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "1A1A1A"))
                            .cornerRadius(16)
                    }

                    if let back = onBack {
                        Button(action: back) {
                            Text("Back")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "666666"))
                        }
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .sheet(isPresented: $showTimePicker) {
            NumberPickerSheet(
                title: "Times per day",
                selectedValue: $timesPerDay,
                options: timeOptions,
                isPresented: $showTimePicker
            )
        }
        .sheet(isPresented: $showMinutesPicker) {
            NumberPickerSheet(
                title: "Minutes per session",
                selectedValue: $minutesPerSession,
                options: minuteOptions,
                isPresented: $showMinutesPicker
            )
        }
    }
}

// Number picker sheet component
struct NumberPickerSheet: View {
    let title: String
    @Binding var selectedValue: Int
    let options: [Int]
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(Color(hex: "666666"))

                Spacer()

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .foregroundColor(Color(hex: "5B51D8"))
                .fontWeight(.semibold)
            }
            .padding()
            .background(Color(hex: "F8F8F8"))

            // Picker
            Picker(title, selection: $selectedValue) {
                ForEach(options, id: \.self) { value in
                    Text("\(value)")
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)
        }
        .presentationDetents([.height(280)])
    }
}
