import AVFoundation
import Foundation

/// Thin AVFoundation wrapper: session lifecycle, segment recording, camera flip.
/// All callbacks are delivered on the main queue.
final class CameraService: NSObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()

    var onReady: (() -> Void)?
    var onUnavailable: (() -> Void)?
    var onPermissionDenied: (() -> Void)?
    var onSegmentFinished: ((URL) -> Void)?
    var onFlipped: ((Bool) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.harulog.camera.session")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false

    // MARK: - Lifecycle

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] videoGranted in
            guard let self else { return }
            guard videoGranted else {
                DispatchQueue.main.async { self.onPermissionDenied?() }
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                self.sessionQueue.async { self.configureAndRun() }
            }
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
            DispatchQueue.main.async { self.onUnavailable?() }
            return
        }
        if !session.isRunning { session.startRunning() }
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
