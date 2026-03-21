import SwiftUI

struct OnboardingFamiliarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selected: String?

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private let options = [
        (id: "new", label: "This is new for me"),
        (id: "occasionally", label: "I've used them occasionally"),
        (id: "regularly", label: "I use them regularly")
    ]

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 10) {
                            Text("How familiar are you with affirmations?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                                .lineSpacing(10)
                                .multilineTextAlignment(.center)

                            Text("Your experience will be adjusted according to your answer")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))
                                .lineSpacing(7)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 28)
                        .padding(.bottom, 20)

                        Text("💭")
                            .font(.system(size: 48))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 24)

                        VStack(spacing: 12) {
                            ForEach(options, id: \.id) { option in
                                SelectionCard(
                                    title: option.label,
                                    isSelected: selected == option.id
                                ) {
                                    selected = option.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                Button(action: {
                    if let selection = selected {
                        appState.onboardingData.affirmationFamiliarity = selection
                        onNext()
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(selected == nil ? Color(hex: "B0B0B0") : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selected == nil ? Color(hex: "E8E8E8") : Color(hex: "1A1A1A"))
                        .cornerRadius(16)
                }
                .disabled(selected == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 12)
            }
        }
    }
}
