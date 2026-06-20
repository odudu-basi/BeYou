import SwiftUI

/// Full-screen affirmation experience opened from the "Today's Affirmation" card.
/// Reuses the old motivation-tab view (`MotivationView`) and overlays a close
/// button (top-left) and a meditate button (bottom).
@available(iOS 16.0, *)
struct TodayAffirmationDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showFreeMeditationSession = false

    var body: some View {
        ZStack {
            // The full "motivation tab" content: swipeable affirmations,
            // themed background, share / favourite / categories / theme picker.
            MotivationView()

            // Close button — top left
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Meditate button — bottom center
            VStack {
                Spacer()
                Button(action: {
                    AnalyticsManager.shared.trackMeditateTapped(source: "affirmation_detail")
                    showFreeMeditationSession = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "figure.mind.and.body")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Tap to meditate")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                }
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showFreeMeditationSession) {
            FreeMeditationSession()
                .environmentObject(appState)
        }
    }
}
