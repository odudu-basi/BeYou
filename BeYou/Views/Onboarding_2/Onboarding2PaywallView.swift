import SwiftUI
import SuperwallKit

struct Onboarding2PaywallView: View {
    let onPurchased: () -> Void
    let onSkipped: () -> Void

    @State private var hasPresented = false
    @State private var skipAttempts = 0
    @State private var didPresentEver = false
    @State private var registerAttempts = 0

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
        registerAttempts += 1

        let handler = PaywallPresentationHandler()
        handler.onPresent { _ in
            didPresentEver = true
            skipAttempts = 0
            AnalyticsManager.shared.trackPaywallShown(placement: "onboarding_paywall")
        }
        handler.onDismiss { _, result in
            AnalyticsManager.shared.trackPaywallDismissed(
                placement: "onboarding_paywall",
                result: paywallResultName(result)
            )
            switch result {
            case .purchased, .restored:
                onPurchased()
            default:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall()
                }
            }
        }
        handler.onSkip { _ in
            if SubscriptionManager.shared.isProUser {
                onSkipped()
            } else {
                skipAttempts += 1
                if skipAttempts > 3 {
                    onSkipped()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPaywall()
                    }
                }
            }
        }

        Superwall.shared.register(placement: "onboarding_paywall", handler: handler) {
            onPurchased()
        }

        // Safety net: if the paywall hasn't appeared within 6s (e.g. Superwall's config is
        // still downloading on a fresh install), retry a few times — and after that, move on
        // rather than stranding the user on a blank screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            guard !didPresentEver else { return }
            if registerAttempts < 4 {
                showPaywall()
            } else {
                onSkipped()
            }
        }
    }
}
