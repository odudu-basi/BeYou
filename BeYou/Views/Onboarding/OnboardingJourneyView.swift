import SwiftUI

struct OnboardingJourneyView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    // Animation states
    @State private var typewriterText: String = ""
    @State private var subtitleOpacity: Double = 0
    @State private var cardAppeared: [Bool] = Array(repeating: false, count: 9) // 8 days + 1 checkpoint
    @State private var buttonOpacity: Double = 0

    private let fullTitle = "Your 7-Day Journey"
    private let typewriterSpeed: Double = 0.06

    private let days: [(day: String, title: String, description: String, emoji: String)] = [
        (
            "TODAY",
            "Set Your Intention",
            "Pick the apps that waste your time and set your first limit.",
            "🎯"
        ),
        (
            "DAY 1",
            "Your First Pause",
            "BeYou's shield pauses you before opening distracting apps. Breathe and decide.",
            "🛡️"
        ),
        (
            "DAY 2",
            "The Urge Fades",
            "The urge to scroll passes in seconds. Your discipline score grows each time.",
            "🌊"
        ),
        (
            "DAY 3",
            "Words Shape Reality",
            "Explore affirmations crafted for your goals. Speak them out loud.",
            "✨"
        ),
        (
            "DAY 4",
            "Reclaim Your Morning",
            "Set a morning Disconnect Schedule so your first hour belongs to you.",
            "🌅"
        ),
        (
            "DAY 5",
            "Speak It Into Existence",
            "Say your affirmations with conviction. Manifestation starts here.",
            "🗣️"
        ),
        (
            "DAY 6",
            "Fill the Space",
            "Screen time is dropping. Fill that space with what truly matters.",
            "🌿"
        ),
        (
            "DAY 7",
            "This Is You Now",
            "Less screen time, more discipline, a growing streak. This is who you're becoming.",
            "🏆"
        )
    ]

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 10) {
                            Text(typewriterText)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)

                            Text("Here's how BeYou transforms your\nrelationship with your phone")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .opacity(subtitleOpacity)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 28)

                        // Timeline
                        VStack(spacing: 0) {
                            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                                let cardIndex = index <= 4 ? index : index + 1 // account for checkpoint at index 5

                                HStack(alignment: .top, spacing: 16) {
                                    // Timeline column
                                    VStack(spacing: 0) {
                                        // Circle
                                        ZStack {
                                            Circle()
                                                .fill(index == 0 ? Color(hex: "1A1A1A") : Color.white)
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color(hex: index == 0 ? "1A1A1A" : "D0D0D0"), lineWidth: 2)
                                                )

                                            Text(day.emoji)
                                                .font(.system(size: 16))
                                        }

                                        // Line
                                        if index < days.count - 1 {
                                            Rectangle()
                                                .fill(Color(hex: "E0E0E0"))
                                                .frame(width: 2)
                                                .frame(maxHeight: .infinity)
                                        }
                                    }
                                    .frame(width: 36)

                                    // Card
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(day.day)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(index == 0 ? .white : Color(hex: "999999"))
                                            .tracking(1.2)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(index == 0 ? Color(hex: "1A1A1A") : Color(hex: "F0F0F0"))
                                            )

                                        Text(day.title)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color(hex: "1A1A1A"))

                                        Text(day.description)
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "777777"))
                                            .lineSpacing(3)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white)
                                    .cornerRadius(14)
                                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                                    .padding(.bottom, index < days.count - 1 ? 8 : 0)
                                }
                                .opacity(cardAppeared[cardIndex] ? 1 : 0)
                                .offset(y: cardAppeared[cardIndex] ? 0 : 20)

                                // Mid-week checkpoint after Day 4
                                if index == 4 {
                                    HStack(spacing: 16) {
                                        VStack(spacing: 0) {
                                            Rectangle()
                                                .fill(Color(hex: "E0E0E0"))
                                                .frame(width: 2, height: 8)
                                        }
                                        .frame(width: 36)

                                        HStack(spacing: 10) {
                                            Text("🎯")
                                                .font(.system(size: 20))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Mid-Week Check-In")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Color(hex: "1A1A1A"))
                                                Text("You're halfway there — your habits are already shifting")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Color(hex: "999999"))
                                            }
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(hex: "E0E0E0"), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                                        )
                                        .padding(.bottom, 8)
                                    }
                                    .opacity(cardAppeared[5] ? 1 : 0)
                                    .offset(y: cardAppeared[5] ? 0 : 20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                // Continue button
                Button(action: onNext) {
                    Text("Let's Begin")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "1A1A1A"))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 12)
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Typewriter effect for header
        typewriterText = ""
        for (charIndex, character) in fullTitle.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + typewriterSpeed * Double(charIndex)) {
                typewriterText += String(character)
            }
        }

        // Fade in subtitle after typewriter finishes
        let typewriterDuration = typewriterSpeed * Double(fullTitle.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + typewriterDuration) {
            withAnimation(.easeOut(duration: 0.5)) {
                subtitleOpacity = 1
            }
        }

        // Staggered fade-in for day cards (after subtitle appears)
        let cardsStartDelay = typewriterDuration + 0.3
        for i in 0..<cardAppeared.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + cardsStartDelay + Double(i) * 0.35) {
                withAnimation(.easeOut(duration: 0.8)) {
                    cardAppeared[i] = true
                }
            }
        }

        // Fade in button after all cards
        let buttonDelay = cardsStartDelay + Double(cardAppeared.count) * 0.35 + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + buttonDelay) {
            withAnimation(.easeOut(duration: 0.5)) {
                buttonOpacity = 1
            }
        }
    }
}
