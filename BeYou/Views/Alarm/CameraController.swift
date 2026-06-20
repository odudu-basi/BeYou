import SwiftUI
import AVFoundation
import Combine

/// Owns the capture session + photo output for the camera-based missions, and
/// performs the actual still capture. Shared by ItemSearchMissionView and
/// PhotoMissionView so both can snap a photo that becomes a Morning Memory.
final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.odudu.BeYou.camera.session")
    private var configured = false
    private var captureCompletion: ((Data?) -> Void)?

    @Published var torchOn = false

    // MARK: - Lifecycle

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
            break // denied/restricted — preview stays black, capture returns nil
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: camera),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }

                self.session.commitConfiguration()
                self.configured = true
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        setTorch(false)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    // MARK: - Capture

    /// Snaps a still and returns its encoded image data (nil if the camera is
    /// unavailable, e.g. simulator or denied permission) on the main thread.
    func capturePhoto(completion: @escaping (Data?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning, self.configured else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.captureCompletion = completion
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    // MARK: - Flashlight

    func toggleTorch() { setTorch(!torchOn) }

    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            DispatchQueue.main.async { self.torchOn = on }
        } catch {
            print("🔦 Torch error: \(error)")
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let data = photo.fileDataRepresentation()
        let completion = captureCompletion
        captureCompletion = nil
        DispatchQueue.main.async { completion?(data) }
    }
}

// MARK: - Camera Preview

/// A UIView whose backing layer IS the camera preview layer, so UIKit keeps it sized
/// to the view automatically — no manual frame management, no zero-bounds race.
final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}
