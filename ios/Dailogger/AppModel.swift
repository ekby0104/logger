import AVFoundation
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
        case camera, edit, viewer, blog, trim
        var id: String { rawValue }
    }

    /// Clips are capped at this length, both recorded and imported.
    static let maxClipSeconds = 5

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
    var zoomLevel: CGFloat = 1
    var hasUltraWide = false
    var isTorchOn = false

    // Library import
    var isImporting = false
    /// Video picked from the library that is longer than the clip limit and
    /// needs trimming before it becomes a draft.
    var trimVideoURL: URL?

    // Location
    @ObservationIgnored let location = LocationService()
    var currentPlaceName: String?
    @ObservationIgnored private var currentCoordinate: CLLocationCoordinate2D?

    // Draft (Edit screen)
    var draftCaption = ""
    var draftMood: Mood = .calm
    var draftThumbnail: UIImage?
    /// Exact length of the merged clip, measured from the file. The on-screen
    /// timer only counts whole seconds, so it is never used for saving.
    var draftDuration: TimeInterval?
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
        camera.onFlipped = { [weak self] isFront in
            self?.isFrontCamera = isFront
            if isFront { self?.isTorchOn = false } // no torch on the front camera
        }
        camera.onZoomCapability = { [weak self] hasUltraWide in
            self?.hasUltraWide = hasUltraWide
        }
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
        zoomLevel = 1
        isTorchOn = false
        camera.setZoom(1)
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isRecording {
            stopTimer()
            segments.append(max(elapsed, 1))
            elapsed = 0
            isRecording = false
            if cameraReady { camera.stopRecording() }
        } else {
            let remaining = Self.maxClipSeconds - recordedSeconds
            guard remaining > 0 else {
                flashToast(String(localized: "Clips are up to 5 seconds"))
                return
            }
            isRecording = true
            if cameraReady {
                // File-level backstop slightly above the timer cut so the
                // UI stop lands first in the normal case.
                camera.setMaxSegmentDuration(Double(remaining) + 0.4)
                camera.startRecording()
            }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.elapsed += 1
                if self.recordedSeconds >= Self.maxClipSeconds, self.isRecording {
                    self.toggleRecord()
                    self.flashToast(String(localized: "Clips are up to 5 seconds"))
                }
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

    func setZoom(_ level: CGFloat) {
        zoomLevel = level
        camera.setZoom(level)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func toggleTorch() {
        isTorchOn.toggle()
        camera.setTorch(isTorchOn)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func goToEdit() {
        guard recordedSeconds > 0 else {
            flashToast(String(localized: "Record a moment first"))
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
                if let duration = try? await AVURLAsset(url: merged).load(.duration),
                   duration.seconds.isFinite, duration.seconds > 0 {
                    self?.draftDuration = duration.seconds
                }
                self?.draftThumbnail = await VideoComposer.thumbnail(for: merged)
            } catch {
                self?.flashToast(String(localized: "Couldn't process the clip"))
            }
            self?.isMerging = false
        }
    }

    // MARK: - Library import

    func importPickedImage(_ image: UIImage) {
        guard !isImporting else { return }
        isImporting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let url = try await VideoComposer.stillVideo(from: image, duration: 3)
                await self.startImportedDraft(url: url)
            } catch {
                self.flashToast(String(localized: "Couldn't load that item"))
            }
            self.isImporting = false
        }
    }

    func importPickedVideo(_ url: URL) {
        guard !isImporting else { return }
        isImporting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let seconds = (try? await AVURLAsset(url: url).load(.duration))?.seconds ?? 0
            if seconds <= 0 {
                self.flashToast(String(localized: "Couldn't load that item"))
            } else if seconds > Double(Self.maxClipSeconds) + 0.05 {
                // Longer than the clip limit — pick the 5 seconds to keep.
                self.trimVideoURL = url
                self.overlay = .trim
            } else {
                await self.startImportedDraft(url: url)
            }
            self.isImporting = false
        }
    }

    func cancelTrim() {
        trimVideoURL = nil
        overlay = .camera
    }

    func confirmTrim(start: Double) {
        guard let url = trimVideoURL, !isImporting else { return }
        isImporting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let trimmed = try await VideoComposer.trim(
                    url: url, start: start, duration: Double(Self.maxClipSeconds)
                )
                self.trimVideoURL = nil
                await self.startImportedDraft(url: trimmed)
            } catch {
                self.flashToast(String(localized: "Couldn't load that item"))
            }
            self.isImporting = false
        }
    }

    /// Puts an imported clip into the normal draft pipeline and opens Edit.
    @MainActor
    private func startImportedDraft(url: URL) async {
        resetCapture()
        draftVideoTempURL = url
        if let duration = try? await AVURLAsset(url: url).load(.duration),
           duration.seconds.isFinite, duration.seconds > 0 {
            draftDuration = duration.seconds
        }
        draftThumbnail = await VideoComposer.thumbnail(for: url)
        overlay = .edit
    }

    // MARK: - Saving

    func saveMoment(context: ModelContext) {
        // Editing an existing moment: update it in place.
        if let editing = editingMoment {
            editing.caption = TextInput.sanitize(draftCaption, limit: TextInput.captionLimit)
            editing.mood = draftMood
            resetCapture()
            viewerMoment = nil
            overlay = nil
            flashToast(String(localized: "Moment updated"))
            return
        }

        // New moment from the camera flow. Prefer the measured length of the
        // merged file; the whole-second timer count is only a fallback.
        let seconds = draftDuration ?? TimeInterval(max(recordedSeconds, 1))
        let caption = TextInput.sanitize(draftCaption, limit: TextInput.captionLimit)
        let id = UUID()

        var videoName: String?
        var thumbnailName: String?
        if let tempURL = draftVideoTempURL {
            videoName = MediaStore.persistVideo(from: tempURL, id: id)
            if let thumbnail = draftThumbnail {
                thumbnailName = MediaStore.persistThumbnail(thumbnail, id: id)
                ThumbnailStore.store(thumbnail, for: thumbnailName)
            }
        }

        let moment = Moment(
            id: id,
            createdAt: .now,
            title: String(caption.prefix(14)),
            caption: caption,
            mood: draftMood,
            duration: seconds,
            placeName: currentPlaceName ?? String(localized: "Somewhere today"),
            latitude: currentCoordinate?.latitude,
            longitude: currentCoordinate?.longitude,
            videoFileName: videoName,
            thumbnailFileName: thumbnailName
        )
        context.insert(moment)

        resetCapture()
        overlay = nil
        tab = .today
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        flashToast(String(localized: "Saved to your timeline"))
        refreshWidgetAndReminder(context: context)
    }

    func deleteMoment(_ moment: Moment, context: ModelContext) {
        MediaStore.deleteFile(named: moment.videoFileName)
        MediaStore.deleteFile(named: moment.thumbnailFileName)
        ThumbnailStore.invalidate(moment.thumbnailFileName)
        if viewerMoment?.id == moment.id {
            viewerMoment = nil
            if overlay == .viewer { overlay = nil }
        }
        if editingMoment?.id == moment.id {
            editingMoment = nil
            if overlay == .edit { overlay = nil }
        }
        context.delete(moment)
        flashToast(String(localized: "Moment deleted"))
        refreshWidgetAndReminder(context: context)
    }

    /// Opens the blog editor for a day (today by default) with the saved
    /// draft or blank fields. Generation is opt-in via "Write with AI".
    func openBlogEditor(context: ModelContext, for date: Date = .now) {
        blogDate = date
        if let saved = log(for: date, context: context),
           let title = saved.blogTitle,
           let body = saved.blogText {
            blogTitle = title
            blogBody = body
            blogIsAI = saved.blogIsAI ?? false
        } else {
            blogTitle = ""
            blogBody = ""
            blogIsAI = false
        }
        overlay = .blog
    }

    func generateBlogWithAI(context: ModelContext) {
        guard !isWritingBlog else { return }
        let dayMoments = moments(on: blogDate, context: context)
        guard !dayMoments.isEmpty else {
            flashToast(String(localized: "Record a moment first"))
            return
        }
        isWritingBlog = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await BlogWriter.write(for: dayMoments, date: self.blogDate)
            self.blogTitle = result.title
            self.blogBody = result.body
            self.blogIsAI = result.isAIGenerated
            self.isWritingBlog = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func saveBlog(context: ModelContext) {
        blogTitle = TextInput.sanitize(blogTitle, limit: TextInput.blogTitleLimit)
        blogBody = TextInput.sanitize(
            blogBody, limit: TextInput.blogBodyLimit, allowNewlines: true
        )
        let dayMoments = moments(on: blogDate, context: context)
        let log = log(for: blogDate, context: context) ?? {
            let newLog = DailyLog(
                date: Calendar.current.startOfDay(for: blogDate),
                clipCount: dayMoments.count
            )
            context.insert(newLog)
            return newLog
        }()
        if !dayMoments.isEmpty {
            log.clipCount = dayMoments.count
        }
        log.blogTitle = blogTitle
        log.blogText = blogBody
        log.blogIsAI = blogIsAI
        log.isBlogReady = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        flashToast(String(localized: "Blog saved"))
    }

    /// Plays a past day as a story: opens the viewer on the day's first
    /// moment (the viewer scopes navigation to that day). Days with no
    /// moments fall back to the saved blog text.
    func openDayStory(for date: Date, context: ModelContext) {
        if let first = moments(on: date, context: context).first {
            openViewer(first)
        } else if let saved = log(for: date, context: context), saved.blogText != nil {
            openBlog(saved)
        } else {
            flashToast(String(localized: "No moments on this day"))
        }
    }

    /// Opens a saved blog from the archive (Calendar day / Me tab).
    func openBlog(_ log: DailyLog) {
        guard let title = log.blogTitle, let body = log.blogText else {
            flashToast(String(localized: "No blog for this day yet"))
            return
        }
        blogTitle = title
        blogBody = body
        blogIsAI = log.blogIsAI ?? false
        blogDate = log.date
        overlay = .blog
    }

    private func log(for date: Date, context: ModelContext) -> DailyLog? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// Removes leftovers from removed features on devices that had them:
    /// seeded demo content (moments without a video file, logs without blog
    /// text — real saves always have both) and duplicate DailyLogs from the
    /// short-lived auto-blog feature.
    func cleanupLegacyData(context: ModelContext) {
        let allMoments = (try? context.fetch(FetchDescriptor<Moment>())) ?? []
        for moment in allMoments where moment.videoFileName == nil {
            context.delete(moment)
        }

        let calendar = Calendar.current
        let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        for log in logs where log.blogText == nil {
            context.delete(log)
        }
        let remaining = logs.filter { $0.blogText != nil }
        let byDay = Dictionary(grouping: remaining) { calendar.startOfDay(for: $0.date) }
        for (_, dayLogs) in byDay where dayLogs.count > 1 {
            for log in dayLogs.dropFirst() {
                context.delete(log)
            }
        }
    }

    /// One-time fix-up for moments saved before durations were measured
    /// from the file (they were timer-estimated with a 5-second floor).
    /// Opening every video is expensive, so after one successful pass a
    /// flag skips this forever — new saves store the measured length.
    func remeasureDurations(context: ModelContext) {
        let doneKey = "durationsRemeasured.v1"
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }
        let all = (try? context.fetch(FetchDescriptor<Moment>())) ?? []
        Task { @MainActor in
            for moment in all {
                guard let url = moment.videoURL,
                      let duration = try? await AVURLAsset(url: url).load(.duration)
                else { continue }
                let seconds = duration.seconds
                if seconds.isFinite, seconds > 0, abs(seconds - moment.duration) > 0.5 {
                    moment.duration = seconds
                }
            }
            UserDefaults.standard.set(true, forKey: doneKey)
        }
    }

    /// Recomputes streak/today-count for the widget and reschedules the
    /// daily reminder. Called on launch and whenever moments change.
    func refreshWidgetAndReminder(context: ModelContext) {
        let todayMoments = moments(on: .now, context: context)
        let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        let allMoments = (try? context.fetch(FetchDescriptor<Moment>())) ?? []
        let streak = Stats.streak(recordDates: logs.map(\.date) + allMoments.map(\.createdAt))
        WidgetBridge.update(streak: streak, todayCount: todayMoments.count)
        ReminderService.reschedule(hasMomentToday: !todayMoments.isEmpty)
    }

    private func moments(on date: Date, context: ModelContext) -> [Moment] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<Moment>(
            predicate: #Predicate { $0.createdAt >= start && $0.createdAt < end },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
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
        draftDuration = nil
        draftCaption = ""
        isMerging = false
        editingMoment = nil
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
