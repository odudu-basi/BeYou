import SwiftUI
import AVFoundation

struct ItemSearchMissionView: View {
    let items: [String]
    let onMissionComplete: () -> Void

    @State private var selectedItem: String = ""
    @State private var isSpinning = true
    @State private var reelItems: [String] = []
    @State private var reelOffset: CGFloat = 0
    @StateObject private var camera = CameraController()
    @State private var verifying = false
    @State private var verifyAttempts = 0
    @State private var verifyMessage: String?
    @State private var verifySuccess = false
    @State private var rejectionToken = 0
    @State private var capturedImage: UIImage?

    private let itemWidth: CGFloat = 150

    private let itemEmojis: [String: String] = [
        "Toothbrush": "🪥", "Running Faucet": "🚰", "Shoes": "👟",
        "Fridge": "🧊", "Keys": "🔑", "Coffee Mug": "☕",
        "Mirror": "🪞", "Water Bottle": "💧", "Dustpan": "🧹",
        "Toilet": "🚽", "Book": "📕", "Lamp": "💡",
        "TV Remote": "📺", "Front Door": "🚪", "Stove": "🍳",
        "Lotion Bottle": "🧴", "Soap": "🧼", "Plant": "🪴",
        "Plate": "🍽️", "Towel": "🧖", "Backpack": "🎒",
        "Headphones": "🎧", "Shower": "🚿", "Tape": "📦",
        "Kim Kardashian": "👩", "Snoop Dogg": "🐶", "Rubber Duck": "🦆",
    ]

    var body: some View {
        ZStack {
            Color(hex: "F8F8F8").ignoresSafeArea()
            missionCameraView

            if let verifyMessage {
                Text(verifyMessage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background((verifySuccess ? Color(hex: "34C759") : Color.gray).opacity(0.92))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            }

            if verifying {
                AnalyzingOverlay(image: capturedImage, label: selectedItem.lowercased())
            }
        }
        .onAppear {
            startSpinning()
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    // MARK: - Camera Mission View

    private var missionCameraView: some View {
        VStack(spacing: 0) {
            // Header
            Text("BeYou")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Camera view area
            ZStack {
                CameraPreviewView(session: camera.session)
                    .cornerRadius(20)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                VStack {
                    // Find this banner
                    if !isSpinning {
                        VStack(spacing: 10) {
                            Text("FIND THIS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(2)

                            HStack(spacing: 14) {
                                Text(itemEmojis[selectedItem] ?? "❓")
                                    .font(.system(size: 34))

                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 1, height: 34)

                                Text(selectedItem)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .padding(.top, 40)

                        // Respin button
                        Button(action: { startSpinning() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                Text("Respin")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 8)
                    }

                    // Spinning reel — whatever lands in the center band is the pick
                    if isSpinning {
                        Spacer()
                        spinReel
                        Spacer()
                    } else {
                        Spacer()

                        // Bottom instruction
                        Text("Find a \(selectedItem) and snap a photo")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()

            // Camera controls
            if !isSpinning {
                ZStack {
                    // Capture button — centered
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .stroke(Color(hex: "1A1A1A"), lineWidth: 4)
                                .frame(width: 72, height: 72)

                            Circle()
                                .fill(Color(hex: "1A1A1A"))
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(verifying || verifySuccess)

                    // Flashlight toggle — pinned to the right
                    HStack {
                        Spacer()
                        Button(action: { camera.toggleTorch() }) {
                            Image(systemName: camera.torchOn ? "bolt.circle.fill" : "bolt.slash.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(camera.torchOn ? Color(hex: "F5A623") : Color(hex: "1A1A1A").opacity(0.5))
                        }
                    }
                    .padding(.trailing, 40)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Spinning Reel

    private var spinReel: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let centering = w / 2 - itemWidth / 2

            ZStack {
                // Center selection band — the item that lands here is the pick
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.7), lineWidth: 2)
                    )
                    .frame(width: itemWidth, height: itemWidth)

                // The reel of items
                HStack(spacing: 0) {
                    ForEach(reelItems.indices, id: \.self) { i in
                        reelCell(reelItems[i])
                            .frame(width: itemWidth)
                    }
                }
                .frame(width: w, alignment: .leading)
                .offset(x: reelOffset + centering)
            }
            .frame(width: w, height: geo.size.height)
            .clipped()
            .mask(
                LinearGradient(
                    colors: [.clear, .black, .black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .frame(height: itemWidth + 24)
    }

    private func reelCell(_ item: String) -> some View {
        VStack(spacing: 10) {
            Text(itemEmojis[item] ?? "❓")
                .font(.system(size: 52))

            Text(item)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: itemWidth)
    }

    // MARK: - Spinning Logic

    private func startSpinning() {
        guard !items.isEmpty else { return }
        isSpinning = true

        // Travel a FIXED number of slots regardless of how many items are picked,
        // so the scroll speed is the same whether you select 3 items or 20.
        // (Distance = travelSlots × itemWidth, independent of items.count.)
        let travelSlots = 12

        // Shuffle so the order looks fresh and the landed item is random each spin.
        let order = items.shuffled()
        let finalIndex = travelSlots

        // Repeat the shuffled order enough times to fill the travel plus a buffer
        // on each side of the center band.
        let reps = (finalIndex / order.count) + 3
        var reel: [String] = []
        for _ in 0..<reps { reel.append(contentsOf: order) }
        reelItems = reel

        selectedItem = order[finalIndex % order.count]

        // Two phases for anticipation:
        //  1) a spin that eases out, stopping one item short of the target
        //  2) a slow, suspenseful crawl onto the final item
        let spinDuration: Double = 5.5
        let settleDuration: Double = 1.2
        let preFinalIndex = finalIndex - 1

        reelOffset = 0
        withAnimation(.easeOut(duration: spinDuration)) {
            reelOffset = -CGFloat(preFinalIndex) * itemWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            withAnimation(.easeInOut(duration: settleDuration)) {
                reelOffset = -CGFloat(finalIndex) * itemWidth
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration + settleDuration) {
            isSpinning = false
        }
    }

    private func capturePhoto() {
        guard !verifying else { return }
        verifying = true
        withAnimation { verifyMessage = nil }

        camera.capturePhoto { data in
            guard let data, let image = UIImage(data: data) else {
                // No camera available (e.g. simulator) — accept.
                verifying = false
                onMissionComplete()
                return
            }
            capturedImage = image
            Task {
                let analysisStart = Date()
                let result = await MissionPhotoVerifier.verify(image: image, mission: "Item Search", target: selectedItem)
                await MissionAnalyzing.holdFloor(since: analysisStart)
                await MainActor.run {
                    verifyAttempts += 1
                    if result.pass {
                        // Correct → brief green confirmation, then advance.
                        MorningMemoryStore.add(image: image, missionName: "Item Search")
                        verifying = false
                        withAnimation { verifySuccess = true; verifyMessage = MissionPhotoVerifier.praise() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onMissionComplete() }
                    } else if verifyAttempts >= 3 {
                        // Fail open after 3 tries so the user is never trapped.
                        MorningMemoryStore.add(image: image, missionName: "Item Search")
                        verifying = false
                        onMissionComplete()
                    } else {
                        verifying = false
                        rejectionToken += 1
                        let token = rejectionToken
                        withAnimation {
                            verifySuccess = false
                            verifyMessage = MissionPhotoVerifier.friendlyRejection(mission: "Item Search", target: selectedItem)
                        }
                        // Auto-dismiss the message so it doesn't linger.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            if rejectionToken == token {
                                withAnimation { verifyMessage = nil }
                            }
                        }
                    }
                }
            }
        }
    }
}
