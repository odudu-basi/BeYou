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
        handler.onPresent { paywallInfo in
            AnalyticsManager.shared.trackPaywallShown(placement: "onboarding_paywall")
        }
        handler.onDismiss { _, _ in
            handleDismiss()
        }
        handler.onSkip { _ in
            handleDismiss()
        }

        Superwall.shared.register(placement: "onboarding_paywall", handler: handler) {
            // Feature block — user purchased or is already subscribed
            appState.navigateTo(.screenTimeConnect)
        }
    }

    private func handleDismiss() {
        // If user purchased, proceed
        if SubscriptionManager.shared.isProUser {
            appState.navigateTo(.screenTimeConnect)
            return
        }

        // Not subscribed — show paywall again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showPaywall()
        }
    }
}
