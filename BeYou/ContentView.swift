import SwiftUI

@available(iOS 16.0, *)
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.currentScreen {
            case .splash:
                SplashView()
            case .welcome:
                WelcomeView()
            case .onboarding:
                OnboardingCoordinator()
            case .paywall:
                PaywallOnboardingView()
            case .screenTimeConnect:
                ScreenTimeConnectView()
            case .setup:
                SetupCoordinator()
            case .main:
                MainAppView()
            }
        }
        .preferredColorScheme(.light)
    }
}
