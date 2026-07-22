import AVFoundation
import Foundation
import os

/// Thin AVFoundation wrapper: session lifecycle, segment recording, camera flip.
/// All callbacks are delivered on the main queue.
final class CameraService: NSObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()

    private let log = Logger(subsystem: "com.dailogger.app", category: "camera")

    var onReady: (() -> Void)?
    var onUnavailable: (() -> Void)?
    var onPermissionDenied: (() -> Void)?
    var onSegmentFinished: ((URL) -> Void)?
    var onFlipped: ((Bool) -> Void)?
    /// Reports whether the current camera can go ultra-wide (0.5x).
    var onZoomCapability: ((Bool) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.dailogger.camera.session")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    /// Raw zoom factor that equals "1x" on the current device. On a virtual
    /// dual-wide camera raw 1.0 is the ultra-wide, and the first switch-over
    /// factor (usually 2.0) is the main wide lens.
    private var oneXFactor: CGFloat = 1
    /// Display zoom the UI asked for (0.5 / 1 / 2), reapplied after flips.
    private var desiredDisplayZoom: CGFloat = 1

    // MARK: - Lifecycle

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        log.info("start() — video auth status: \(status.rawValue)")

        switch status {
        case .authorized:
            requestAudioThenConfigure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                self.log.info("video permission response: \(granted)")
                if granted {
                    self.requestAudioThenConfigure()
                } else {
                    DispatchQueue.main.async { self.onPermissionDenied?() }
                }
            }
        default: // .denied, .restricted
            DispatchQueue.main.async { self.onPermissionDenied?() }
        }
    }

    private func requestAudioThenConfigure() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                guard let self else { return }
                self.sessionQueue.async { self.configureAndRun() }
            }
        } else {
            sessionQueue.async { [weak self] in self?.configureAndRun() }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() {
        if !isConfigured {
            session.beginConfiguration()
            session.sessionPreset = .high

            if let device = Self.backCamera(),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
                configureZoomBaseline(for: device)
            }
            if let microphone = AVCaptureDevice.default(for: .audio),
               let microphoneInput = try? AVCaptureDeviceInput(device: microphone),
               session.canAddInput(microphoneInput) {
                session.addInput(microphoneInput)
            }
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }
            applyPortraitRotation()
            session.commitConfiguration()
            isConfigured = true
        }

        guard videoInput != nil else {
            // Simulator or no camera hardware — UI falls back to mock recording.
            log.warning("no video input available — falling back to mock recording")
            DispatchQueue.main.async { self.onUnavailable?() }
            return
        }
        if !session.isRunning { session.startRunning() }
        log.info("session running: \(self.session.isRunning)")
        DispatchQueue.main.async { self.onReady?() }
    }

    private func applyPortraitRotation() {
        guard let connection = movieOutput.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        // Record the front camera mirrored, matching what the preview shows —
        // otherwise selfie clips play back flipped from what the user saw.
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = videoInput?.device.position == .front
        }
    }

    // MARK: - Controls

    /// The back camera: prefers the virtual dual-wide device so zooming can
    /// reach the ultra-wide (0.5x) lens; falls back to the plain wide camera.
    private static func backCamera() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// Establishes what "1x" means on this device and applies the desired zoom.
    /// Must be called on the session queue.
    private func configureZoomBaseline(for device: AVCaptureDevice) {
        oneXFactor = device.virtualDeviceSwitchOverVideoZoomFactors.first
            .map { CGFloat(truncating: $0) } ?? 1
        let hasUltraWide = device.position == .back && oneXFactor > 1
        applyZoom(desiredDisplayZoom, to: device)
        DispatchQueue.main.async { self.onZoomCapability?(hasUltraWide) }
    }

    private func applyZoom(_ display: CGFloat, to device: AVCaptureDevice) {
        guard device.position == .back else { return }
        let raw = min(
            max(display * oneXFactor, device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = raw
            device.unlockForConfiguration()
        } catch {
            log.warning("zoom failed: \(error.localizedDescription)")
        }
    }

    /// display: 0.5 / 1 / 2 as shown in the UI.
    func setZoom(_ display: CGFloat) {
        sessionQueue.async { [self] in
            desiredDisplayZoom = display
            guard let device = videoInput?.device else { return }
            applyZoom(display, to: device)
        }
    }

    func setTorch(_ on: Bool) {
        sessionQueue.async { [self] in
            guard let device = videoInput?.device, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                log.warning("torch failed: \(error.localizedDescription)")
            }
        }
    }

    /// Hard backstop so a segment file can never exceed the app's clip limit
    /// even if the UI timer misses the stop.
    func setMaxSegmentDuration(_ seconds: Double) {
        sessionQueue.async { [self] in
            movieOutput.maxRecordedDuration = seconds.isFinite && seconds > 0
                ? CMTime(seconds: seconds, preferredTimescale: 600)
                : .invalid
        }
    }

    func flip() {
        sessionQueue.async { [self] in
            guard let current = videoInput else { return }
            let newPosition: AVCaptureDevice.Position =
                current.device.position == .back ? .front : .back
            let newDevice = newPosition == .back
                ? Self.backCamera()
                : AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            guard let device = newDevice,
                let input = try? AVCaptureDeviceInput(device: device) else { return }

            session.beginConfiguration()
            session.removeInput(current)
            if session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
            } else {
                session.addInput(current)
            }
            applyPortraitRotation()
            session.commitConfiguration()
            configureZoomBaseline(for: videoInput?.device ?? device)

            let isFront = newPosition == .front
            DispatchQueue.main.async { self.onFlipped?(isFront) }
        }
    }

    func startRecording() {
        sessionQueue.async { [self] in
            guard session.isRunning,
                  movieOutput.connection(with: .video) != nil,
                  !movieOutput.isRecording else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("segment-\(UUID().uuidString).mov")
            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        sessionQueue.async { [self] in
            if movieOutput.isRecording { movieOutput.stopRecording() }
        }
    }

    func discardSegments(_ urls: [URL]) {
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        // A non-nil error can still leave a playable file (e.g. interruption).
        let fileExists = FileManager.default.fileExists(atPath: outputFileURL.path)
        guard error == nil || fileExists else { return }
        DispatchQueue.main.async { self.onSegmentFinished?(outputFileURL) }
    }
}
