import SwiftUI

struct OnboardingTriedBeforeView: View {
    @EnvironmentObject var appState: AppState
    @State private var selected: Set<String> = []

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private let options: [(id: String, emoji: String, label: String)] = [
        ("nothing", "🚫", "Nothing yet"),
        ("screen-limiters", "⏱️", "Screen time limiters"),
        ("uninstalling", "🗑️", "Uninstalling addictive apps"),
        ("browser-only", "🌐", "Using browser-only versions"),
        ("digital-detox", "🧘", "Digital detox"),
        ("grayscale", "🔘", "Grayscale mode"),
        ("willpower", "💪", "Pure willpower (didn't last)")
    ]

    private let maxSelections = 3

    private var firstFeeling: String {
        let feelingLabels: [String: String] = [
            "irritable": "irritable", "not-present": "not present", "drained": "mentally drained",
            "regretful": "regretful", "empty": "empty", "powerless": "powerless", "anxious": "anxious"
        ]
        if let first = appState.onboardingData.feelings.first {
            return feelingLabels[first] ?? "this way"
        }
        return "this way"
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You said these apps make you \(firstFeeling), so we'd like to ask:")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))
                                .lineSpacing(7)

                            Text("What have you already tried?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                                .lineSpacing(10)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                        Text("🕐")
                            .font(.system(size: 48))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 20)

                        // Options
                        VStack(spacing: 10) {
                            ForEach(options, id: \.id) { option in
                                let isSelected = selected.contains(option.id)
                                let isDisabled = !isSelected && option.id != "nothing" && selected.count >= maxSelections && !selected.contains("nothing")

                                Button(action: {
                                    toggleOption(option.id)
                                }) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? Color.white : Color(hex: "F0F0F0"))
                                                .frame(width: 40, height: 40)

                                            if isSelected {
                                                Text("✓")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Color(hex: "1A1A1A"))
                                            } else {
                                                Text(option.emoji)
                                                    .font(.system(size: 20))
                                            }
                                        }

                                        Text(option.label)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(isSelected ? .white : (isDisabled ? Color(hex: "999999") : Color(hex: "1A1A1A")))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .background(isSelected ? Color(hex: "1A1A1A") : Color.white)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isSelected ? Color(hex: "1A1A1A") : Color(hex: "EBEBEB"), lineWidth: 1.5)
                                    )
                                    .opacity(isDisabled ? 0.4 : 1.0)
                                }
                                .disabled(isDisabled)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                // Bottom button
                Button(action: {
                    appState.onboardingData.triedBefore = Array(selected)
                    onNext()
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(selected.isEmpty ? Color(hex: "B0B0B0") : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selected.isEmpty ? Color(hex: "E8E8E8") : Color(hex: "1A1A1A"))
                        .cornerRadius(16)
                }
                .disabled(selected.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 12)
            }
        }
    }

    private func toggleOption(_ id: String) {
        if id == "nothing" {
            selected = ["nothing"]
            return
        }

        var newSelected = selected.filter { $0 != "nothing" }
        if newSelected.contains(id) {
            newSelected.remove(id)
        } else if newSelected.count < maxSelections {
            newSelected.insert(id)
        }
        selected = newSelected
    }
}
