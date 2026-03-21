import SwiftUI

struct SetupScheduleInfoView: View {
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 40)

                        // Logo tilted like home page
                        Image("be-you-icon")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(20)
                            .rotationEffect(.degrees(-5))

                        VStack(spacing: 12) {
                            Text("Focus Blocks")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .tracking(-0.3)
                                .multilineTextAlignment(.center)

                            Text("For when you need total focus")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "999999"))
                        }

                        // Explanation card
                        VStack(alignment: .leading, spacing: 16) {
                            featureRow(
                                icon: "clock.fill",
                                color: "6C5CE7",
                                title: "Set a time window",
                                description: "Choose when you want apps blocked — during work, study, or bedtime."
                            )

                            Divider()

                            featureRow(
                                icon: "lock.fill",
                                color: "E74C3C",
                                title: "Apps stay locked",
                                description: "Unlike intentions, focus blocks don't allow opens. The apps are fully blocked until the time is up."
                            )

                            Divider()

                            featureRow(
                                icon: "hand.tap.fill",
                                color: "27AE60",
                                title: "Easy to manage",
                                description: "You can always stop a focus block early from the Home tab if plans change."
                            )
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "EBEBEB"), lineWidth: 1)
                        )

                        // Where to find it
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "6C5CE7"))

                            Text("Set up focus blocks in the **Schedule** tab whenever you're ready.")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "666666"))
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(Color(hex: "F0EDFF"))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                Button(action: onNext) {
                    Text("Continue")
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

    private func featureRow(icon: String, color: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: color))
                .frame(width: 36, height: 36)
                .background(Color(hex: color).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "888888"))
                    .lineSpacing(3)
            }
        }
    }
}
