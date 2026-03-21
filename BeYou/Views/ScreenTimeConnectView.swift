import SwiftUI
import FamilyControls

@available(iOS 16.0, *)
struct ScreenTimeConnectView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @State private var isRequestingAuthorization = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title & subtitle
            VStack(spacing: 12) {
                Text("Connect BeYou to\nScreen Time")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)

                Text("Your data is completely private and\nnever leaves your device.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Mock system dialog preview
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Text("\"BeYou\" Would Like to\nAccess Screen Time")
                        .font(.system(size: 17, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)

                    Text("Providing \"BeYou\" access to Screen Time may allow it to see your activity data, restrict content, and limit the usage of apps and websites.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "3C3C43").opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                HStack(spacing: 0) {
                    Text("Continue")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "007AFF"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)

                    Divider()
                        .frame(height: 44)

                    Text("Don't Allow")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "007AFF"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "F2F2F2").opacity(0.95))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, 44)

            // "Tap Continue" hint
            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .medium))
                Text("Tap Continue")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.black)
            .padding(.top, 16)

            Spacer()

            if showError {
                Text("Screen Time access is required. You can enable it later in Settings.")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }

            Button(action: requestPermission) {
                if isRequestingAuthorization {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(16)
                } else {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(16)
                }
            }
            .disabled(isRequestingAuthorization)
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "E8F4FD"), Color(hex: "D4ECFC")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func requestPermission() {
        isRequestingAuthorization = true
        showError = false

        Task {
            do {
                try await screenTimeManager.requestAuthorization()
                await MainActor.run {
                    isRequestingAuthorization = false
                    if screenTimeManager.authorizationStatus == .approved {
                        appState.navigateTo(.setup)
                    } else {
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isRequestingAuthorization = false
                    showError = true
                }
            }
        }
    }
}
