import SwiftUI
import SuperwallKit

/// Bare presenter for the reactive hard gate. Shown in place of the app whenever an onboarded user
/// is NOT subscribed. It has no visible UI of its own — just a plain background while it presents
/// the SAME Superwall paywall as onboarding (`onboarding_paywall`, tagged `source: reactive_gate`).
///
/// If the paywall is dismissed without buying, it re-presents — so the app is never reachable
/// without an active entitlement. There is no manual "unlock"/"restore" here: the Superwall paywall
/// carries its own Restore link, and unlocking is automatic (the root gate swaps this view out for
/// the app the moment `SubscriptionManager.isProUser` becomes true).
@available(iOS 16.0, *)
struct SubscriptionGateView: View {
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
            AnalyticsManager.shared.trackPaywallShown(placement: "onboarding_paywall", source: "reactive_gate")
        }
        handler.onDismiss { _, result in
            AnalyticsManager.shared.trackPaywallDismissed(
                placement: "onboarding_paywall",
                result: paywallResultName(result),
                source: "reactive_gate"
            )
            switch result {
            case .purchased, .restored:
                break   // isProUser flips → the root gate swaps to the app automatically.
            default:
                // Dismissed without buying → re-present. The app is never reachable without an
                // active entitlement.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall()
                }
            }
        }
        // Same placement as onboarding, tagged so the funnel is distinguishable in analytics.
        Superwall.shared.register(
            placement: "onboarding_paywall",
            params: ["source": "reactive_gate"],
            handler: handler
        ) {
            // Feature granted (real purchase / already entitled) — isProUser will reflect it.
        }

        // If the paywall hasn't appeared yet (config still downloading / slow video), keep
        // re-presenting until it does. Never falls through to the app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
            guard !didPresentEver else { return }
            showPaywall()
        }
    }
}
