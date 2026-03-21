import SwiftUI

struct OnboardingLoadingPlanView: View {
    let onNext: () -> Void

    @State private var progress: Double = 0.0
    @State private var currentLabel: String = "Analyzing your habits..."
    @State private var showCheckmark = false

    private let labels = [
        "Analyzing your habits...",
        "Calculating screen time impact...",
        "Building your personalized plan...",
        "Almost ready..."
    ]

    var body: some View {
        ZStack {
            Color(hex: "1A1A1A").ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated icon
                ZStack {
                    if showCheckmark {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "4CAF50"))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(progress * 360))
                            .overlay(
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 56, height: 56)
                                    .rotationEffect(.degrees(progress * 720))
                            )
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: showCheckmark)

                VStack(spacing: 12) {
                    Text(currentLabel)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .animation(.easeInOut(duration: 0.3), value: currentLabel)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: geo.size.width * progress, height: 6)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 40)
                }

                Spacer()
            }
        }
        .onAppear {
            startLoading()
        }
    }

    private func startLoading() {
        // Phase 1: 0% -> 30%
        withAnimation {
            currentLabel = labels[0]
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { progress = 0.3 }
        }

        // Phase 2: 30% -> 60%
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { currentLabel = labels[1] }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { progress = 0.6 }
        }

        // Phase 3: 60% -> 85%
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { currentLabel = labels[2] }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { progress = 0.85 }
        }

        // Phase 4: 85% -> 100%
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation { currentLabel = labels[3] }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation { progress = 1.0 }
        }

        // Done - show checkmark then advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            showCheckmark = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
            onNext()
        }
    }
}
