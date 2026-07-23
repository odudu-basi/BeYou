import SwiftUI

@available(iOS 16.0, *)
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var subscriptions = SubscriptionManager.shared

    var body: some View {
        Group {
            switch appState.currentScreen {
            case .splash:
                SplashView()
            case .welcome, .onboarding, .paywall:
                OnboardingCoordinator2()
            case .screenTimeConnect:
                ScreenTimeConnectView()
            case .setup:
                SetupCoordinator()
            case .main:
                // Reactive hard gate: an onboarded user who isn't subscribed sees the locked
                // paywall gate instead of the app — at any moment. `hasResolvedEntitlements`
                // avoids flashing it at a real subscriber before RevenueCat resolves on launch.
                // The instant isProUser changes (lapse mid-session, or purchase), this re-renders.
                if subscriptions.hasResolvedEntitlements && !subscriptions.isProUser {
                    SubscriptionGateView()
                } else {
                    MainAppView()
                }
            }
        }
        .preferredColorScheme(.light)
        .buttonStyle(HapticButtonStyle())   // app-wide: every button taps with a haptic
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
