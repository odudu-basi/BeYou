import SwiftUI

struct OnboardingTransformView: View {
    @EnvironmentObject var appState: AppState
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private let appNames: [String: String] = [
        "tiktok": "TikTok", "youtube": "YouTube", "instagram": "Instagram", "games": "Games",
        "twitter": "Twitter", "reddit": "Reddit", "snapchat": "Snapchat", "facebook": "Facebook",
        "netflix": "Netflix", "other": "Other"
    ]

    private let feelingLabels: [String: String] = [
        "irritable": "Irritable", "not-present": "Not Present", "drained": "Drained",
        "regretful": "Regretful", "empty": "Empty", "powerless": "Powerless", "anxious": "Anxious"
    ]

    private let feelingTransform: [String: (emoji: String, label: String)] = [
        "irritable": ("😌", "Calm"),
        "not-present": ("🌿", "Present"),
        "drained": ("⚡", "Energized"),
        "regretful": ("🎯", "Intentional"),
        "empty": ("✨", "Fulfilled"),
        "powerless": ("💪", "In Control"),
        "anxious": ("🧘", "At Peace")
    ]

    private var selectedApps: [String] {
        Array(appState.onboardingData.timeWasterApps.prefix(3))
    }

    private var selectedFeelings: [String] {
        Array(appState.onboardingData.feelings.prefix(3))
    }

    private var positiveOutcomes: [(emoji: String, label: String)] {
        selectedFeelings.map { feeling in
            feelingTransform[feeling] ?? ("✨", "Better")
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressBar(current: currentStep, total: totalSteps)

                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Here's what changes when you commit")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "999999"))

                            Text("Your Transformation")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                        }
                        .padding(.top, 28)
                        .padding(.bottom, 28)

                        // Current State Section
                        VStack(spacing: 0) {
                            Text("Current State")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "FF6B6B"))
                                .padding(.bottom, 20)

                            // App chips - centered
                            CenteredFlowLayout(spacing: 10) {
                                ForEach(selectedApps, id: \.self) { appId in
                                    Text(appNames[appId] ?? appId)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 18)
                                        .background(Color(hex: "2A2A2A"))
                                        .cornerRadius(20)
                                }
                            }

                            Text("leads to")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "666666"))
                                .italic()
                                .padding(.vertical, 16)

                            // Feeling chips - centered
                            CenteredFlowLayout(spacing: 10) {
                                ForEach(selectedFeelings, id: \.self) { feeling in
                                    Text(feelingLabels[feeling] ?? feeling)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "FF6B6B"))
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 18)
                                        .background(Color(hex: "3D2020"))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color(hex: "FF6B6B").opacity(0.25), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 28)
                        .padding(.horizontal, 24)
                        .background(Color(hex: "1A1A1A"))
                        .cornerRadius(20)

                        // Divider with arrow
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(hex: "E0E0E0"))
                                .frame(height: 1)

                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: "E0E0E0"), lineWidth: 1.5)
                                    )

                                Text("↓")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(hex: "4CAF50"))
                            }
                            .padding(.horizontal, 12)

                            Rectangle()
                                .fill(Color(hex: "E0E0E0"))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)

                        // With Be You Section
                        VStack(spacing: 20) {
                            HStack(spacing: 8) {
                                Text("With")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Image("be-you-icon")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .cornerRadius(8)

                                Text("Be You")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                            }

                            CenteredFlowLayout(spacing: 10) {
                                ForEach(positiveOutcomes.indices, id: \.self) { index in
                                    HStack(spacing: 8) {
                                        Text(positiveOutcomes[index].emoji)
                                            .font(.system(size: 18))
                                        Text(positiveOutcomes[index].label)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(hex: "2E7D32"))
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 20)
                                    .background(Color(hex: "E8F5E9"))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color(hex: "4CAF50").opacity(0.25), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.bottom, 28)

                        // Research Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("📊  The Research")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))

                            Text("Studies show that reducing screen time by just 1 hour a day can significantly improve mood, sleep quality, and overall mental well-being.")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "666666"))
                                .lineSpacing(8)
                        }
                        .padding(22)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "EBEBEB"), lineWidth: 1.5)
                        )
                        .padding(.bottom, 30)
                    }
                    .padding(.horizontal, 24)
                }

                // Bottom button
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
            }
        }
    }
}

// Centered flow layout - centers each row of chips
struct CenteredFlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = CenteredFlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = CenteredFlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let row = result.rowForIndex[index]
            let rowWidth = result.rowWidths[row]
            let offsetX = (bounds.width - rowWidth) / 2
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x + offsetX,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: .unspecified
            )
        }
    }

    struct CenteredFlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        var rowWidths: [CGFloat] = []
        var rowForIndex: [Int] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var currentRowWidth: CGFloat = 0
            var currentRow = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    rowWidths.append(currentRowWidth - spacing)
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                    currentRowWidth = 0
                    currentRow += 1
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                rowForIndex.append(currentRow)
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                currentRowWidth = currentX
            }

            // Last row
            if currentRowWidth > 0 {
                rowWidths.append(currentRowWidth - spacing)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// Simple flow layout for wrapping chips (left-aligned)
struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
