import SwiftUI
import SuperwallKit

@available(iOS 16.0, *)
struct PaywallOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var hasPresented = false

    var body: some View {
        Color(hex: "F8F8F8")
            .ignoresSafeArea()
            .onAppear {
                guard !hasPresented else { return }
                hasPresented = true
                showPaywall()
            }
    }

    private func showPaywall() {
        let handler = PaywallPresentationHandler()
        handler.onPresent { _ in
            AnalyticsManager.shared.trackPaywallShown(placement: "onboarding_paywall")
        }
        handler.onDismiss { _, result in
            switch result {
            case .purchased, .restored:
                appState.navigateTo(.screenTimeConnect)
            default:
                // Declined — re-show paywall
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall()
                }
            }
        }
        handler.onSkip { _ in
            // Superwall skipped — check if already subscribed
            if SubscriptionManager.shared.isProUser {
                appState.navigateTo(.screenTimeConnect)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall()
                }
            }
        }

        Superwall.shared.register(placement: "onboarding_paywall", handler: handler) {
            appState.navigateTo(.screenTimeConnect)
        }
    }
}
