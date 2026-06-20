import SwiftUI

@available(iOS 16.0, *)
struct ContentView: View {
    @EnvironmentObject var appState: AppState

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
                MainAppView()
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
