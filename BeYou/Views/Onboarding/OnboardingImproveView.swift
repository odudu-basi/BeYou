import SwiftUI

struct OnboardingImproveView: View {
    @EnvironmentObject var appState: AppState
    @State private var selected: Set<String> = []

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private let options = [
        (id: "meditation", label: "Meditation"),
        (id: "exercise", label: "Exercise and nutrition"),
        (id: "journaling", label: "Journaling"),
        (id: "support", label: "Support from others"),
        (id: "nature", label: "Spending time in nature"),
        (id: "therapy", label: "Therapy")
    ]

    private let maxSelections = 3

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("How do you improve your mental health?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                                .lineSpacing(10)

                            Text("You can select more than one option")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))
                        }
                        .padding(.top, 28)
                        .padding(.bottom, 20)

                        Text("🧠")
                            .font(.system(size: 48))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 24)

                        VStack(spacing: 12) {
                            ForEach(options, id: \.id) { option in
                                let isSelected = selected.contains(option.id)
                                let isDisabled = !isSelected && selected.count >= maxSelections

                                Button(action: {
                                    toggleSelection(option.id)
                                }) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? Color(hex: "1A1A1A") : Color(hex: "D0D0D0"), lineWidth: 2)
                                                .frame(width: 24, height: 24)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(isSelected ? Color(hex: "1A1A1A") : Color.clear)
                                                )

                                            if isSelected {
                                                Text("✓")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }

                                        Text(option.label)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(isSelected ? Color(hex: "1A1A1A") : (isDisabled ? Color(hex: "999999") : Color(hex: "1A1A1A")))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .background(Color.white)
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

                Button(action: {
                    appState.onboardingData.improveMethods = Array(selected)
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

    private func toggleSelection(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < maxSelections {
            selected.insert(id)
        }
    }
}
