import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Image("be-you-icon")
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 0.4,
                       height: UIScreen.main.bounds.width * 0.4)
                .cornerRadius(30)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            // Fade in + bounce in from small to large
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }

            // Gentle pulse after 1.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    scale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        scale = 1.0
                    }
                }
            }

            // Navigate to welcome after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                appState.navigateTo(.welcome)
            }
        }
    }
}
