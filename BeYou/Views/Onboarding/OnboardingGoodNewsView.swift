import SwiftUI

struct OnboardingGoodNewsView: View {
    @EnvironmentObject var appState: AppState
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    // Typewriter state
    @State private var line1Text = ""
    @State private var daysText = ""
    @State private var line2Text = ""
    @State private var showFooter = false
    @State private var showButton = false

    private var screenTime: Int {
        appState.onboardingData.currentScreenTime ?? 8
    }

    private var goalTime: Int {
        appState.onboardingData.goalTime ?? 2
    }

    private var daysSaved: Int {
        Int(round(Double((screenTime - goalTime) * 365) / 24.0))
    }

    private var fullLine1: String { "The good news is that Be You\ncan help you get back" }
    private var fullDays: String { "\(daysSaved) days+" }
    private var fullLine2: String { "of your life free from distractions,\nand help you become who you\nactually want to be." }

    var body: some View {
        ZStack {
            Color(hex: "1A1A1A").ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        Text(line1Text)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)

                        if !daysText.isEmpty {
                            Text(daysText)
                                .font(.system(size: 72, weight: .heavy))
                                .foregroundColor(Color(hex: "4CAF50"))
                                .padding(.vertical, 16)
                        }

                        if !line2Text.isEmpty {
                            Text(line2Text)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex: "A0A0A0"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }

                // Bottom section
                VStack(spacing: 0) {
                    if showFooter {
                        Text("Based on reducing from \(screenTime)h to \(goalTime)h daily with Be You.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "666666"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.bottom, 16)
                            .transition(.opacity)
                    }

                    if showButton {
                        Button(action: onNext) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .cornerRadius(16)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 12)
            }
        }
        .onAppear {
            startTypewriter()
        }
    }

    private func startTypewriter() {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        var delay: Double = 0.0

        // Line 1
        typewrite(fullLine1, into: "line1", delay: &delay, charDelay: 0.04, haptic: haptic)

        // Days - pop in with heavy haptic
        delay += 0.3
        let daysDelay = delay
        DispatchQueue.main.asyncAfter(deadline: .now() + daysDelay) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.daysText = self.fullDays
            }
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.impactOccurred()
        }
        delay += 0.6

        // Line 2
        typewrite(fullLine2, into: "line2", delay: &delay, charDelay: 0.035, haptic: haptic)

        // Show footer and button
        delay += 0.5
        let finalDelay = delay
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {
            withAnimation(.easeIn(duration: 0.4)) {
                showFooter = true
                showButton = true
            }
        }
    }

    private func typewrite(_ text: String, into target: String, delay: inout Double, charDelay: Double, haptic: UIImpactFeedbackGenerator) {
        let chars = Array(text)
        for (i, char) in chars.enumerated() {
            let currentDelay = delay + Double(i) * charDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                appendChar(char, for: target)
                if i % 2 == 0 {
                    haptic.impactOccurred()
                }
            }
        }
        delay += Double(chars.count) * charDelay
    }

    private func appendChar(_ char: Character, for target: String) {
        switch target {
        case "line1": line1Text.append(char)
        case "line2": line2Text.append(char)
        default: break
        }
    }
}
