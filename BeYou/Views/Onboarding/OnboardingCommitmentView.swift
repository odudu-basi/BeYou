import SwiftUI

struct OnboardingCommitmentView: View {
    @EnvironmentObject var appState: AppState

    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    @State private var fillProgress: CGFloat = 0.0
    @State private var isHolding = false
    @State private var isCommitted = false
    @State private var holdTimer: Timer?

    private let holdDuration: TimeInterval = 2.0 // seconds to hold

    private var userName: String {
        appState.onboardingData.name ?? "there"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressBar(current: currentStep, total: totalSteps)

            // Back button
            HStack {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .font(.system(size: 20))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 32) {
                // Title
                VStack(spacing: 12) {
                    Text("\(userName),")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.black)

                    Text("Are you committed to building\na habit of speaking more\npositively to yourself and\nreducing your screen time?")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "4B5563"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Fingerprint scanner
                VStack(spacing: 16) {
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color(hex: "E2E8F0"), lineWidth: 4)
                            .frame(width: 140, height: 140)

                        // Fill circle (progress)
                        Circle()
                            .trim(from: 0, to: fillProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "3B82F6"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))

                        // Filled background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "3B82F6").opacity(fillProgress * 0.2),
                                        Color(hex: "8B5CF6").opacity(fillProgress * 0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 132, height: 132)

                        // Fingerprint icon
                        Image(systemName: isCommitted ? "checkmark" : "touchid")
                            .font(.system(size: 50, weight: isCommitted ? .bold : .regular))
                            .foregroundColor(
                                isCommitted
                                    ? Color(hex: "10B981")
                                    : (isHolding ? Color(hex: "3B82F6") : Color(hex: "9CA3AF"))
                            )
                            .scaleEffect(isHolding ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isHolding)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isHolding && !isCommitted {
                                    startHolding()
                                }
                            }
                            .onEnded { _ in
                                if !isCommitted {
                                    stopHolding()
                                }
                            }
                    )

                    Text(isCommitted ? "You're committed!" : "Hold to commit")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isCommitted ? Color(hex: "10B981") : Color(hex: "9CA3AF"))
                }
            }

            Spacer()

            // Continue button (only visible after commitment)
            if isCommitted {
                Button(action: onNext) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "3B82F6"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color(hex: "F8F8F8").ignoresSafeArea())
    }

    // MARK: - Hold Logic

    private func startHolding() {
        isHolding = true
        let interval: TimeInterval = 0.02
        let increment = CGFloat(interval / holdDuration)

        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            withAnimation(.linear(duration: interval)) {
                fillProgress += increment
            }

            if fillProgress >= 1.0 {
                timer.invalidate()
                holdTimer = nil
                fillProgress = 1.0
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isCommitted = true
                    isHolding = false
                }
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }

    private func stopHolding() {
        isHolding = false
        holdTimer?.invalidate()
        holdTimer = nil

        // Reset progress if not committed
        if !isCommitted {
            withAnimation(.easeOut(duration: 0.3)) {
                fillProgress = 0.0
            }
        }
    }
}
