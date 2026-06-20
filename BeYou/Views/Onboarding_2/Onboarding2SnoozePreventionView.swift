import SwiftUI

struct Onboarding2SnoozePreventionView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        Onboarding2Template(
            title: "BeYou prevents you\nfrom snoozing",
            currentStep: currentStep,
            totalSteps: totalSteps,
            isNextEnabled: true,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Graph card
                VStack(spacing: 16) {
                    Text("Time spent snoozing")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Graph
                    SnoozeGraph()
                        .frame(height: 160)

                    Text("Most users report becoming a morning person after just 2 weeks.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "888888"))
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            }
        }
    }
}

// MARK: - Snooze Graph

struct SnoozeGraph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Horizontal dashed lines
                ForEach(0..<3, id: \.self) { i in
                    let y = h * CGFloat(i + 1) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color(hex: "E8E8E8"), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                // Traditional alarm line (red, goes up)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.45))
                    path.addCurve(
                        to: CGPoint(x: w * 0.4, y: h * 0.35),
                        control1: CGPoint(x: w * 0.15, y: h * 0.5),
                        control2: CGPoint(x: w * 0.3, y: h * 0.3)
                    )
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.1),
                        control1: CGPoint(x: w * 0.55, y: h * 0.42),
                        control2: CGPoint(x: w * 0.8, y: h * 0.1)
                    )
                }
                .stroke(Color(hex: "FF6B6B"), lineWidth: 2)

                // Fill under red line (traces red line path exactly, closes at top)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.45))
                    path.addCurve(
                        to: CGPoint(x: w * 0.4, y: h * 0.35),
                        control1: CGPoint(x: w * 0.15, y: h * 0.5),
                        control2: CGPoint(x: w * 0.3, y: h * 0.3)
                    )
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.1),
                        control1: CGPoint(x: w * 0.55, y: h * 0.42),
                        control2: CGPoint(x: w * 0.8, y: h * 0.1)
                    )
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.closeSubpath()
                }
                .fill(Color(hex: "FF6B6B").opacity(0.08))

                // BeYou line (black, goes down)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.4))
                    path.addCurve(
                        to: CGPoint(x: w * 0.5, y: h * 0.5),
                        control1: CGPoint(x: w * 0.2, y: h * 0.35),
                        control2: CGPoint(x: w * 0.35, y: h * 0.55)
                    )
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.85),
                        control1: CGPoint(x: w * 0.65, y: h * 0.45),
                        control2: CGPoint(x: w * 0.85, y: h * 0.85)
                    )
                }
                .stroke(Color(hex: "1A1A1A"), lineWidth: 2.5)

                // Fill under black line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.4))
                    path.addCurve(
                        to: CGPoint(x: w * 0.5, y: h * 0.5),
                        control1: CGPoint(x: w * 0.2, y: h * 0.35),
                        control2: CGPoint(x: w * 0.35, y: h * 0.55)
                    )
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.85),
                        control1: CGPoint(x: w * 0.65, y: h * 0.45),
                        control2: CGPoint(x: w * 0.85, y: h * 0.85)
                    )
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(Color(hex: "1A1A1A").opacity(0.05))

                // Start circle (black line)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color(hex: "1A1A1A"), lineWidth: 2))
                    .frame(width: 10, height: 10)
                    .position(x: 0, y: h * 0.4)

                // End circle (black line)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color(hex: "1A1A1A"), lineWidth: 2))
                    .frame(width: 10, height: 10)
                    .position(x: w, y: h * 0.85)

                // Labels
                VStack(spacing: 2) {
                    Text("Traditional alarm")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "FF6B6B"))
                }
                .position(x: w * 0.75, y: h * 0.25)

                HStack(spacing: 4) {
                    Image("be-you-icon")
                        .resizable()
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    Text("With BeYou")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
                .position(x: w * 0.15, y: h * 0.65)

                // X-axis labels
                Text("Day 1")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "999999"))
                    .position(x: w * 0.08, y: h + 12)

                Text("Day 30")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "999999"))
                    .position(x: w * 0.92, y: h + 12)
            }
        }
    }
}
