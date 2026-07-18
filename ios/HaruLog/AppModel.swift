import Foundation
import SwiftData
import SwiftUI

/// App-wide UI state: tab selection, overlay routing, capture state, drafts, toast.
/// Mirrors the wireframe's component state machine.
@Observable
final class AppModel {
    enum Tab: Hashable {
        case today, timeline, calendar, profile
    }

    enum Overlay: String, Identifiable {
        case camera, edit, viewer
        var id: String { rawValue }
    }

    var tab: Tab = .today
    var overlay: Overlay?

    // Capture state
    var isRecording = false
    var elapsed = 0
    var segments: [Int] = []
    var isFrontCamera = false

    // Draft (Edit screen)
    var draftCaption = ""
    var draftMood: Mood = .calm

    // Viewer
    var viewerMoment: Moment?

    // Toast
    var toast: String?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    var recordedSeconds: Int {
        segments.reduce(0, +) + elapsed
    }

    var elapsedLabel: String {
        "\(elapsed / 60):" + String(format: "%02d", elapsed % 60)
    }

    // MARK: - Navigation

    func openCamera() {
        isRecording = false
        elapsed = 0
        segments = []
        draftMood = .calm
        overlay = .camera
    }

    func closeOverlay() {
        stopTimer()
        isRecording = false
        elapsed = 0
        segments = []
        overlay = nil
    }

    func openViewer(_ moment: Moment) {
        viewerMoment = moment
        overlay = .viewer
    }

    func closeViewer() {
        viewerMoment = nil
        overlay = nil
    }

    func editFromViewer() {
        if let moment = viewerMoment {
            draftCaption = moment.caption
            draftMood = moment.mood
        }
        overlay = .edit
    }

    // MARK: - Recording

    func toggleRecord() {
        if isRecording {
            stopTimer()
            segments.append(max(elapsed, 1))
            elapsed = 0
            isRecording = false
        } else {
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.elapsed += 1
            }
        }
    }

    func flipCamera() {
        isFrontCamera.toggle()
    }

    func goToEdit() {
        guard recordedSeconds > 0 else {
            flashToast("Record a moment first")
            return
        }
        stopTimer()
        isRecording = false
        draftCaption = ""
        overlay = .edit
    }

    // MARK: - Saving

    func saveMoment(context: ModelContext) {
        let seconds = max(recordedSeconds, 5)
        let moment = Moment(
            createdAt: .now,
            title: draftCaption.isEmpty ? "New moment" : String(draftCaption.prefix(14)),
            caption: draftCaption.isEmpty ? "A moment just captured." : draftCaption,
            mood: draftMood,
            duration: TimeInterval(seconds),
            placeName: "Seongsu-dong, Seoul"
        )
        context.insert(moment)

        stopTimer()
        overlay = nil
        tab = .today
        draftCaption = ""
        isRecording = false
        elapsed = 0
        segments = []
        flashToast("Saved to your timeline")
    }

    func makeBlog() {
        flashToast("Your daily blog is ready")
    }

    // MARK: - Toast

    func flashToast(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
