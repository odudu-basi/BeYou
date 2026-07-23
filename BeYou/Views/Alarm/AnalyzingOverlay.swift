import SwiftUI

/// Shown while the AI verifies a mission photo: the just-captured shot, heavily
/// blurred, with an "Analyzing <thing> …" label and animated dots.
struct AnalyzingOverlay: View {
    let image: UIImage?
    let label: String
    @State private var animate = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 30)
                    .clipped()
                    .overlay(Color.black.opacity(0.15))
            } else {
                Color.black.opacity(0.6)
            }

            HStack(spacing: 9) {
                Text("Analyzing \(label)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .opacity(animate ? 1 : 0.25)
                            .animation(
                                .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                                value: animate
                            )
                    }
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 8)
        }
        .ignoresSafeArea()
        .onAppear { animate = true }
    }
}

/// Enforces a minimum on-screen time for the "Analyzing…" overlay. The AI verdict can come back
/// almost instantly, which makes the check feel fake (a flash). Call `holdFloor(since:)` right
/// after the verifier returns and before hiding the overlay so a fast result still reads as a
/// real analysis. Same "floor" idea as the alarm-save spinner.
enum MissionAnalyzing {
    static let minimumDuration: TimeInterval = 4

    /// Sleeps just long enough that the total elapsed time since `start` reaches `minimumDuration`.
    static func holdFloor(since start: Date) async {
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < minimumDuration {
            try? await Task.sleep(nanoseconds: UInt64((minimumDuration - elapsed) * 1_000_000_000))
        }
    }
}
