import SwiftUI

struct Onboarding2Template<Content: View>: View {
    let title: String
    let currentStep: Int
    let totalSteps: Int
    let isNextEnabled: Bool
    let buttonText: String
    let onNext: () -> Void
    let onBack: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        currentStep: Int,
        totalSteps: Int,
        isNextEnabled: Bool = true,
        buttonText: String = "Continue",
        onNext: @escaping () -> Void,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.isNextEnabled = isNextEnabled
        self.buttonText = buttonText
        self.onNext = onNext
        self.onBack = onBack
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: back button + progress
            HStack(spacing: 12) {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "E8E8E8"))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "1A1A1A"))
                            .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Title
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)

            // Content
            ScrollView {
                VStack(spacing: 0) {
                    content
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Continue button
            Button(action: onNext) {
                Text(buttonText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isNextEnabled ? .white : Color(hex: "B0B0B0"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isNextEnabled ? Color.black : Color(hex: "E8E8E8"))
                    .cornerRadius(16)
            }
            .disabled(!isNextEnabled)
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color(hex: "F8F8F8"))
    }
}
