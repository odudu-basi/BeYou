import SwiftUI

struct OnboardingCurrentRateView: View {
    @EnvironmentObject var appState: AppState
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    // Typewriter state
    @State private var line1Text = ""
    @State private var daysText = ""
    @State private var line2Text = ""
    @State private var monthsText = ""
    @State private var italicText = ""
    @State private var showFooter = false
    @State private var showButton = false
    @State private var isAnimating = true

    private var screenTime: Int {
        appState.onboardingData.currentScreenTime ?? 8
    }

    private var daysThisYear: Int {
        Int(round(Double(screenTime * 365) / 24.0))
    }

    private var monthsEquivalent: Int {
        Int(round(Double(daysThisYear) / 30.0))
    }

    // Full strings
    private var fullLine1: String { "At your current rate, you'll spend" }
    private var fullDays: String { "\(daysThisYear) days" }
    private var fullLine2: String { "on your phone over the next year" }
    private var fullMonths: String { "That's \(monthsEquivalent) months of your life\nlooking down at a screen." }
    private var fullItalic: String { "Yep, you read this right." }

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
                                .foregroundColor(Color(hex: "FF6B6B"))
                                .padding(.vertical, 8)
                        }

                        if !line2Text.isEmpty {
                            Text(line2Text)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                        }

                        if !monthsText.isEmpty {
                            Spacer().frame(height: 40)

                            Text(monthsText)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex: "A0A0A0"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                        }

                        if !italicText.isEmpty {
                            Text(italicText)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))
                                .italic()
                                .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }

                // Bottom section
                VStack(spacing: 0) {
                    if showFooter {
                        Text("Projection based on \(screenTime)h daily screen time over 365 days.")
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
        typewrite(fullLine1, into: &line1Text, delay: &delay, charDelay: 0.04, haptic: haptic)

        // Days - appears with a heavier haptic
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
        typewrite(fullLine2, into: &line2Text, delay: &delay, charDelay: 0.04, haptic: haptic)

        // Months text
        delay += 0.5
        typewrite(fullMonths, into: &monthsText, delay: &delay, charDelay: 0.035, haptic: haptic)

        // Italic text
        delay += 0.4
        typewrite(fullItalic, into: &italicText, delay: &delay, charDelay: 0.05, haptic: haptic)

        // Show footer and button
        delay += 0.5
        let finalDelay = delay
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {
            withAnimation(.easeIn(duration: 0.4)) {
                showFooter = true
                showButton = true
                isAnimating = false
            }
        }
    }

    private func typewrite(_ text: String, into binding: inout String, delay: inout Double, charDelay: Double, haptic: UIImpactFeedbackGenerator) {
        let chars = Array(text)
        for (i, char) in chars.enumerated() {
            let currentDelay = delay + Double(i) * charDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                // Use a direct update approach via notification
                appendChar(char, for: text)
                // Haptic on every 2nd character (not too aggressive)
                if i % 2 == 0 {
                    haptic.impactOccurred()
                }
            }
        }
        delay += Double(chars.count) * charDelay
    }

    // Because we can't capture inout bindings in closures, route through identifiable strings
    private func appendChar(_ char: Character, for source: String) {
        if source == fullLine1 {
            line1Text.append(char)
        } else if source == fullLine2 {
            line2Text.append(char)
        } else if source == fullMonths {
            monthsText.append(char)
        } else if source == fullItalic {
            italicText.append(char)
        }
    }
}
