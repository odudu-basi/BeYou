import SwiftUI
import AVFoundation
import CoreImage
import Combine

// MARK: - Front-camera frame sampler

/// Runs the FRONT camera and, while sampling, grabs a downscaled frame every ~1.2s via a video
/// data output (no shutter sound, unlike repeated photo capture). Used by the exercise missions
/// to collect a handful of frames for AI verification.
final class ExerciseCameraSampler: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.odudu.BeYou.exercise.camera")
    private let ciContext = CIContext()
    private var configured = false

    private var sampling = false
    private var lastSampleTime: CFTimeInterval = 0
    private let sampleInterval: CFTimeInterval = 1.2
    private var collected: [UIImage] = []
    private let maxFrames = 12

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                AnalyticsManager.shared.trackPermissionResult(type: "camera", granted: granted)
                guard granted else { return }
                self?.configureAndRun()
            }
        default:
            break
        }
    }

    private func configureAndRun() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                if let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                   let input = try? AVCaptureDeviceInput(device: cam),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.setSampleBufferDelegate(self, queue: self.queue)
                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }
                // Portrait orientation for the sampled frames.
                if #available(iOS 17.0, *),
                   let conn = self.videoOutput.connection(with: .video),
                   conn.isVideoRotationAngleSupported(90) {
                    conn.videoRotationAngle = 90
                }

                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.sampling = false
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// Begin collecting frames (call when recording starts).
    func beginSampling() {
        queue.async { [weak self] in
            self?.collected = []
            self?.lastSampleTime = 0
            self?.sampling = true
        }
    }

    /// Stop collecting and hand back the frames on the main thread.
    func endSampling(completion: @escaping ([UIImage]) -> Void) {
        queue.async { [weak self] in
            self?.sampling = false
            let frames = self?.collected ?? []
            DispatchQueue.main.async { completion(frames) }
        }
    }
}

extension ExerciseCameraSampler: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard sampling, collected.count < maxFrames else { return }
        let now = CACurrentMediaTime()
        guard now - lastSampleTime >= sampleInterval else { return }
        lastSampleTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        collected.append(UIImage(cgImage: cg))
    }
}

// MARK: - Exercise mission view

/// Records the user doing an exercise (Push Ups / Squats) for `seconds`, then verifies the
/// sampled frames with AI. Fails OPEN after 3 tries so a groggy user is never trapped.
struct ExerciseMissionView: View {
    let exercise: String            // "Push Ups" or "Squats"
    var seconds: Int = 15
    let onMissionComplete: () -> Void

    @StateObject private var camera = ExerciseCameraSampler()

    @State private var recording = false
    @State private var remaining = 0
    @State private var ringTrim: CGFloat = 1.0
    @State private var countdownTimer: Timer?

    @State private var verifying = false
    @State private var verifyAttempts = 0
    @State private var verifyMessage: String?
    @State private var verifySuccess = false
    @State private var rejectionToken = 0

    private var accent: Color { Color(hex: AlarmItem.colorHex(for: exercise)) }

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
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white).scaleEffect(1.4)
                        Text("Checking your \(exercise.lowercased())…")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            remaining = seconds
            camera.start()
        }
        .onDisappear {
            countdownTimer?.invalidate()
            camera.stop()
        }
    }

    private var missionCameraView: some View {
        VStack(spacing: 0) {
            Text("BeYou")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)

            ZStack(alignment: .top) {
                CameraPreviewView(session: camera.session)
                    .cornerRadius(20)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Countdown ring card (top of frame, like the competitor's rep counter).
                countdownCard
                    .padding(.top, 40)

                // Bottom instruction
                VStack {
                    Spacer()
                    Text(recording
                         ? "Keep going — \(exercise.lowercased())!"
                         : "Prop your phone up, then press record and do \(exercise.lowercased())")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 24)
                }
            }

            Spacer()

            // Record button — centered.
            Button(action: startRecording) {
                ZStack {
                    Circle()
                        .stroke(accent, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(recording ? Color.red : accent)
                        .frame(width: recording ? 30 : 60, height: recording ? 30 : 60)
                        .cornerRadius(recording ? 6 : 30)
                }
            }
            .disabled(recording || verifying || verifySuccess)
            .padding(.bottom, 40)
        }
    }

    private var countdownCard: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: ringTrim)
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(remaining)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 84, height: 84)

            Text(exercise)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    // MARK: - Recording flow

    private func startRecording() {
        guard !recording, !verifying else { return }
        recording = true
        remaining = seconds
        ringTrim = 1.0
        withAnimation { verifyMessage = nil }

        camera.beginSampling()

        // Deplete the ring smoothly over the duration.
        withAnimation(.linear(duration: Double(seconds))) { ringTrim = 0 }

        // Tick the displayed number down each second.
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            remaining = max(0, remaining - 1)
            if remaining <= 0 { t.invalidate() }
        }

        // End of recording → collect frames → verify.
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(seconds)) {
            finishRecording()
        }
    }

    private func finishRecording() {
        countdownTimer?.invalidate()
        recording = false
        withAnimation { verifying = true }

        camera.endSampling { frames in
            Task {
                let analysisStart = Date()
                let result = await ExerciseVideoVerifier.verify(frames: frames, exercise: exercise)
                await MissionAnalyzing.holdFloor(since: analysisStart)
                await MainActor.run {
                    verifyAttempts += 1
                    withAnimation { verifying = false }

                    if result.pass || verifyAttempts >= 3 {
                        withAnimation { verifySuccess = true; verifyMessage = ExerciseVideoVerifier.praise() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onMissionComplete() }
                    } else {
                        rejectionToken += 1
                        let token = rejectionToken
                        remaining = seconds
                        ringTrim = 1.0
                        withAnimation {
                            verifySuccess = false
                            verifyMessage = ExerciseVideoVerifier.friendlyRejection(exercise: exercise)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            if rejectionToken == token { withAnimation { verifyMessage = nil } }
                        }
                    }
                }
            }
        }
    }
}
