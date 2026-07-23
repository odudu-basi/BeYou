import SwiftUI
import SuperwallKit

struct Onboarding2PaywallView: View {
    let onPurchased: () -> Void
    let onSkipped: () -> Void

    @State private var hasPresented = false
    @State private var didPresentEver = false

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
            didPresentEver = true
            AnalyticsManager.shared.trackPaywallShown(placement: "onboarding_paywall", source: "onboarding")
        }
        handler.onDismiss { _, result in
            AnalyticsManager.shared.trackPaywallDismissed(
                placement: "onboarding_paywall",
                result: paywallResultName(result),
                source: "onboarding"
            )
            switch result {
            case .purchased, .restored:
                onPurchased()
            default:
                // Dismissed without buying → re-present. There is NO "give up and let them in":
                // the only way past onboarding is a real purchase or restore.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall()
                }
            }
        }
        handler.onSkip { _ in
            // Superwall chose not to present (e.g. the user is already entitled, or config isn't
            // ready yet). Only advance if they ACTUALLY have an active entitlement; otherwise keep
            // trying to present. A non-subscriber is never let through here.
            if SubscriptionManager.shared.isProUser {
                onSkipped()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showPaywall()
                }
            }
        }

        Superwall.shared.register(
            placement: "onboarding_paywall",
            params: ["source": "onboarding"],
            handler: handler
        ) {
            // Superwall runs this feature block whenever it "grants" the feature — which, if the
            // campaign/paywall is NOT strictly gated (or on a holdout), also happens on a plain
            // dismiss. A bare onPurchased() here let non-payers through (the escape we kept seeing).
            // Only advance if the user ACTUALLY has an active entitlement; real purchases still
            // advance via onDismiss(.purchased) above, so this can't block a genuine buyer.
            if SubscriptionManager.shared.isProUser {
                onPurchased()
            }
            // else: not entitled — do nothing; onDismiss/onSkip re-present the paywall.
        }

        // If the paywall hasn't appeared yet (e.g. Superwall's config is still downloading on a
        // fresh install, or a video paywall is slow to load), keep re-presenting until it does.
        // We deliberately never fall through to letting the user in — the paywall is the only way
        // past onboarding.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
            guard !didPresentEver else { return }
            showPaywall()
        }
    }
}
