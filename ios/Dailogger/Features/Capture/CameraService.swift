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

    private let sessionQueue = DispatchQueue(label: "com.dailogger.camera.session")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false

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

            if let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back
            ),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
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
        if let connection = movieOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    // MARK: - Controls

    func flip() {
        sessionQueue.async { [self] in
            guard let current = videoInput else { return }
            let newPosition: AVCaptureDevice.Position =
                current.device.position == .back ? .front : .back
            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: newPosition
            ),
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
