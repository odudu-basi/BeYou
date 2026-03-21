import SwiftUI

struct OnboardingReligionView: View {
    @EnvironmentObject var appState: AppState
    @State private var selected: String?

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private let options = [
        (id: "yes", label: "Yes"),
        (id: "no", label: "No"),
        (id: "spiritual", label: "Spiritual but not religious")
    ]

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Are you religious?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                                .lineSpacing(10)
                                .padding(.bottom, 8)

                            Text("This information will be used to tailor your affirmations to your beliefs")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))
                                .lineSpacing(7)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                        Text("🙏")
                            .font(.system(size: 48))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 20)

                        // Options
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

                // Bottom button
                Button(action: {
                    if let selection = selected {
                        appState.onboardingData.religion = selection
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
