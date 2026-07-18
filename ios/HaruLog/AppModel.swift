import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import UIKit

/// App-wide UI state: tab selection, overlay routing, capture state, drafts, toast.
/// Owns the CameraService and bridges its callbacks into observable state.
@Observable
final class AppModel {
    enum Tab: Hashable {
        case today, timeline, calendar, profile
    }

    enum Overlay: String, Identifiable {
        case camera, edit, viewer, blog
        var id: String { rawValue }
    }

    var tab: Tab = .today
    var overlay: Overlay?

    // Capture state (UI)
    var isRecording = false
    var elapsed = 0
    var segments: [Int] = []
    var isFrontCamera = false

    // Camera hardware
    @ObservationIgnored let camera = CameraService()
    var cameraReady = false
    var cameraUnavailable = false
    var cameraPermissionDenied = false
    var segmentURLs: [URL] = []

    // Location
    @ObservationIgnored let location = LocationService()
    var currentPlaceName: String?
    @ObservationIgnored private var currentCoordinate: CLLocationCoordinate2D?

    // Draft (Edit screen)
    var draftCaption = ""
    var draftMood: Mood = .calm
    var draftThumbnail: UIImage?
    var isMerging = false
    /// Non-nil when editing an existing moment (from the viewer) instead of creating a new one.
    var editingMoment: Moment?
    @ObservationIgnored private var draftVideoTempURL: URL?

    // Viewer
    var viewerMoment: Moment?

    // Daily blog
    var blogTitle = ""
    var blogBody = ""
    var blogIsAI = false
    var blogDate: Date = .now
    var isWritingBlog = false

    // Toast
    var toast: String?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init() {
        camera.onReady = { [weak self] in self?.cameraReady = true }
        camera.onUnavailable = { [weak self] in self?.cameraUnavailable = true }
        camera.onPermissionDenied = { [weak self] in self?.cameraPermissionDenied = true }
        camera.onFlipped = { [weak self] isFront in self?.isFrontCamera = isFront }
        camera.onSegmentFinished = { [weak self] url in
            self?.segmentURLs.append(url)
            self?.mergeWhenReady()
        }
        location.onPlaceResolved = { [weak self] name, coordinate in
            self?.currentPlaceName = name
            self?.currentCoordinate = coordinate
        }
    }

    var recordedSeconds: Int {
        segments.reduce(0, +) + elapsed
    }

    var elapsedLabel: String {
        "\(elapsed / 60):" + String(format: "%02d", elapsed % 60)
    }

    // MARK: - Navigation

    func openCamera() {
        resetCapture()
        draftMood = .calm
        overlay = .camera
        location.requestPlace()
    }

    func closeOverlay() {
        resetCapture()
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
        guard let moment = viewerMoment else { return }
        editingMoment = moment
        draftCaption = moment.caption
        draftMood = moment.mood
        overlay = .edit
    }

    // MARK: - Recording

    func toggleRecord() {
        if isRecording {
            stopTimer()
            segments.append(max(elapsed, 1))
            elapsed = 0
            isRecording = false
            if cameraReady { camera.stopRecording() }
        } else {
            isRecording = true
            if cameraReady { camera.startRecording() }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.elapsed += 1
            }
        }
    }

    func flipCamera() {
        if cameraReady {
            camera.flip()
        } else {
            isFrontCamera.toggle()
        }
    }

    func goToEdit() {
        guard recordedSeconds > 0 else {
            flashToast("Record a moment first")
            return
        }
        if isRecording {
            toggleRecord() // finalize the in-flight segment
        }
        stopTimer()
        isRecording = false
        draftCaption = ""
        overlay = .edit
        mergeWhenReady()
    }

    /// Merges recorded segment files once they have all landed on disk.
    /// Called both when entering Edit and when a late segment file arrives.
    private func mergeWhenReady() {
        guard overlay == .edit,
              !segmentURLs.isEmpty,
              segmentURLs.count >= segments.count,
              draftVideoTempURL == nil,
              !isMerging else { return }

        isMerging = true
        let urls = segmentURLs
        Task { @MainActor [weak self] in
            do {
                let merged = try await VideoComposer.merge(segmentURLs: urls)
                self?.draftVideoTempURL = merged
                self?.draftThumbnail = await VideoComposer.thumbnail(for: merged)
            } catch {
                self?.flashToast("Couldn't process the clip")
            }
            self?.isMerging = false
        }
    }

    // MARK: - Saving

    func saveMoment(context: ModelContext) {
        // Editing an existing moment: update it in place.
        if let editing = editingMoment {
            if !draftCaption.isEmpty {
                editing.caption = draftCaption
            }
            editing.mood = draftMood
            resetCapture()
            viewerMoment = nil
            overlay = nil
            flashToast("Moment updated")
            return
        }

        // New moment from the camera flow.
        let seconds = max(recordedSeconds, 5)
        let id = UUID()

        var videoName: String?
        var thumbnailName: String?
        if let tempURL = draftVideoTempURL {
            videoName = MediaStore.persistVideo(from: tempURL, id: id)
            if let thumbnail = draftThumbnail {
                thumbnailName = MediaStore.persistThumbnail(thumbnail, id: id)
            }
        }

        let moment = Moment(
            id: id,
            createdAt: .now,
            title: draftCaption.isEmpty ? "New moment" : String(draftCaption.prefix(14)),
            caption: draftCaption.isEmpty ? "A moment just captured." : draftCaption,
            mood: draftMood,
            duration: TimeInterval(seconds),
            placeName: currentPlaceName ?? "Somewhere today",
            latitude: currentCoordinate?.latitude,
            longitude: currentCoordinate?.longitude,
            videoFileName: videoName,
            thumbnailFileName: thumbnailName
        )
        context.insert(moment)

        resetCapture()
        overlay = nil
        tab = .today
        flashToast("Saved to your timeline")
    }

    func makeBlog(moments: [Moment], context: ModelContext) {
        guard !moments.isEmpty else {
            flashToast("Record a moment first")
            return
        }
        guard !isWritingBlog else { return }

        // Reuse today's saved blog while the moment count is unchanged.
        if let saved = todayLog(context: context),
           let title = saved.blogTitle,
           let body = saved.blogText,
           saved.clipCount == moments.count {
            blogTitle = title
            blogBody = body
            blogIsAI = saved.blogIsAI ?? false
            blogDate = .now
            overlay = .blog
            return
        }

        isWritingBlog = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await BlogWriter.write(for: moments, date: .now)
            self.blogTitle = result.title
            self.blogBody = result.body
            self.blogIsAI = result.isAIGenerated
            self.blogDate = .now
            self.isWritingBlog = false
            self.overlay = .blog

            let log = self.todayLog(context: context) ?? {
                let newLog = DailyLog(
                    date: Calendar.current.startOfDay(for: .now),
                    clipCount: moments.count
                )
                context.insert(newLog)
                return newLog
            }()
            log.clipCount = moments.count
            log.blogTitle = result.title
            log.blogText = result.body
            log.blogIsAI = result.isAIGenerated
            log.isBlogReady = true
        }
    }

    /// Opens a saved blog from the archive (Calendar day / Me tab).
    func openBlog(_ log: DailyLog) {
        guard let title = log.blogTitle, let body = log.blogText else {
            flashToast("No blog for this day yet")
            return
        }
        blogTitle = title
        blogBody = body
        blogIsAI = log.blogIsAI ?? false
        blogDate = log.date
        overlay = .blog
    }

    private func todayLog(context: ModelContext) -> DailyLog? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        return (try? context.fetch(descriptor))?.first
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

    // MARK: - Private

    private func resetCapture() {
        stopTimer()
        isRecording = false
        elapsed = 0
        segments = []
        camera.discardSegments(segmentURLs)
        segmentURLs = []
        draftVideoTempURL = nil
        draftThumbnail = nil
        draftCaption = ""
        isMerging = false
        editingMoment = nil
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
