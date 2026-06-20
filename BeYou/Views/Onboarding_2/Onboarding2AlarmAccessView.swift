import SwiftUI
import AlarmKit

@available(iOS 26.1, *)
struct Onboarding2AlarmAccessView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?

    @State private var isAuthorized = false
    @State private var showDeniedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress bar and back button
            HStack(spacing: 12) {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }
                }

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
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Alarm icon
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "6C5CE7"))
                        .padding(.bottom, 8)

                    Text("Allow alarm access")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .multilineTextAlignment(.center)

                    Text("BeYou needs alarm access to wake you up on time — even through Do Not Disturb and Silent mode.")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "888888"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)

                    // Why we need it
                    VStack(alignment: .leading, spacing: 16) {
                        reasonRow(
                            icon: "bell.and.waves.left.and.right",
                            title: "Rings through silent mode",
                            description: "Your alarm will always sound, even if your phone is on silent or Do Not Disturb."
                        )

                        reasonRow(
                            icon: "xmark.circle",
                            title: "Can't be snoozed away",
                            description: "The alarm keeps ringing until you complete your mission — no shortcuts."
                        )

                        reasonRow(
                            icon: "lock.shield",
                            title: "Works when phone is locked",
                            description: "Your alarm fires reliably even if the app isn't open."
                        )
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer().frame(height: 60)
                }
            }

            // Allow button
            Button(action: requestAccess) {
                Text(isAuthorized ? "Continue" : "Allow Alarm Access")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "1A1A1A"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Color(hex: "F8F8F8"))
        .alert("Alarm Access Required", isPresented: $showDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Try Again") {
                requestAccess()
            }
        } message: {
            Text("BeYou needs alarm access to work as your alarm clock. Please enable it in Settings to continue.")
        }
        .onAppear {
            let state = AlarmManager.shared.authorizationState
            isAuthorized = state == .authorized
        }
    }

    private func requestAccess() {
        if isAuthorized {
            onNext()
            return
        }

        Task {
            do {
                let state = try await AlarmManager.shared.requestAuthorization()
                await MainActor.run {
                    if state == .authorized {
                        isAuthorized = true
                        onNext()
                    } else {
                        showDeniedAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    showDeniedAlert = true
                }
            }
        }
    }

    private func reasonRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "6C5CE7"))
                .frame(width: 36, height: 36)
                .background(Color(hex: "6C5CE7").opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A1A"))

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "888888"))
                    .lineSpacing(3)
            }
        }
    }
}
