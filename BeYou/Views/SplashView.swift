import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var bounce: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // "BeYou" wordmark (in place of the app icon): pops in, then bounces up and down.
                Text("BeYou")
                    .font(.system(size: 56, weight: .black))
                    .italic()
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .offset(y: bounce)

                Text("never snooze again")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "666666"))
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            // Pop in.
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                scale = 1.0
                opacity = 1.0
            }

            // Once it's settled, start the continuous up/down bounce.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    bounce = -18
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeIn(duration: 0.6)) {
                    textOpacity = 1.0
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    appState.navigateTo(appState.destinationAfterSplash())
                }
            }
        }
    }
}
