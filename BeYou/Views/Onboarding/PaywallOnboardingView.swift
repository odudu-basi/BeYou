import SwiftUI
import RevenueCatUI

@available(iOS 16.0, *)
struct PaywallOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPaywall = true

    var body: some View {
        Color(hex: "F8F8F8")
            .ignoresSafeArea()
            .fullScreenCover(isPresented: $showPaywall, onDismiss: {
                // Proceed regardless of whether user subscribed or dismissed
                appState.navigateTo(.screenTimeConnect)
            }) {
                PaywallView()
                    .onPurchaseCompleted { customerInfo in
                        print("💰 PAYWALL: Purchase completed")
                        SubscriptionManager.shared.syncEntitlementStatus(from: customerInfo)
                        AnalyticsManager.shared.trackPaywallShown(placement: "onboarding_paywall")
                        showPaywall = false
                    }
                    .onRestoreCompleted { customerInfo in
                        print("💰 PAYWALL: Restore completed")
                        SubscriptionManager.shared.syncEntitlementStatus(from: customerInfo)
                        showPaywall = false
                    }
            }
            .onAppear {
                AnalyticsManager.shared.trackPaywallShown(placement: "onboarding_paywall")
            }
    }
}
