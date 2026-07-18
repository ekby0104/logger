import AVFoundation
import SwiftUI
import SwiftData
import UIKit

/// Story-style viewer:
/// - quick tap (< 0.25s) on the left/right half moves to the previous/next moment
/// - holding (>= 0.25s) pauses; releasing resumes without moving
/// - clips play automatically and advance to the next moment when they end
/// - moments without a clip advance after a fixed interval
struct MomentViewerView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Moment.createdAt) private var moments: [Moment]
    @State private var player: AVPlayer?
    @State private var isPaused = false
    @State private var pressStartDate: Date?
    @State private var pauseTask: Task<Void, Never>?

    /// A touch shorter than this is a navigation tap; longer is a hold-to-pause.
    private let holdThreshold = 0.25

    private var current: Moment? {
        model.viewerMoment ?? moments.first
    }

    private var currentIndex: Int {
        guard let current else { return 0 }
        return moments.firstIndex { $0.id == current.id } ?? 0
    }

    var body: some View {
        ZStack {
            HL.camBackground.ignoresSafeArea()

            if let player {
                PlayerLayerView(player: player)
                    .ignoresSafeArea()
            }

            LinearGradient(
                stops: [
                    .init(color: HL.ink.opacity(0.55), location: 0),
                    .init(color: .clear, location: 0.25),
                    .init(color: .clear, location: 0.52),
                    .init(color: HL.ink.opacity(0.85), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in touchBegan() }
                            .onEnded { value in
                                touchEnded(at: value.location, width: geometry.size.width)
                            }
                    )
            }

            if isPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 0) {
                // Progress ticking lives in its own small view so the 10Hz
                // updates never re-render this whole screen.
                ViewerProgressBars(
                    count: moments.count,
                    currentIndex: currentIndex,
                    player: player,
                    isPaused: isPaused,
                    momentID: current?.id,
                    onMockFinished: { step(1) }
                )

                HStack {
                    Spacer()
                    Button {
                        model.closeViewer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(HL.ink.opacity(0.5))
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)

                Spacer()

                if current != nil {
                    HStack {
                        Spacer()
                        editButton
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Identical geometry to the reel overlays: pill + caption at the
            // top-left, 12% of the full frame height from the top, 20pt side
            // margin, 10pt gap (see ReelComposer).
            GeometryReader { geometry in
                if let moment = current {
                    VStack(alignment: .leading, spacing: 10) {
                        metaPill(moment)
                        if !moment.caption.isEmpty {
                            captionBox(moment.caption)
                        }
                    }
                    .padding(.horizontal, 20)
                    .offset(y: geometry.size.height * 0.12)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onAppear { updatePlayer() }
        .onChange(of: model.viewerMoment?.id) { updatePlayer() }
        .onDisappear {
            pauseTask?.cancel()
            tearDownPlayer()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
        ) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === player?.currentItem else { return }
            step(1)
        }
    }

    // MARK: - Touch handling

    /// Touch down: start the hold timer. Pausing only kicks in after the
    /// threshold, so a quick navigation tap never flickers the pause state.
    private func touchBegan() {
        guard pressStartDate == nil else { return }
        pressStartDate = Date()
        pauseTask?.cancel()
        pauseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(holdThreshold))
            guard !Task.isCancelled, pressStartDate != nil else { return }
            setPaused(true)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    /// Touch up: short touch navigates by screen half; a hold just resumes.
    private func touchEnded(at location: CGPoint, width: CGFloat) {
        pauseTask?.cancel()
        let began = pressStartDate ?? Date()
        pressStartDate = nil
        let held = Date().timeIntervalSince(began)

        if isPaused || held >= holdThreshold {
            setPaused(false)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            step(location.x < width / 2 ? -1 : 1)
        }
    }

    // MARK: - Playback driving

    private func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            player?.pause()
        } else {
            player?.play()
        }
    }

    /// Reuses a single AVPlayer and swaps its item, so the previous clip's
    /// audio stops the moment the viewer moves to another moment.
    private func updatePlayer() {
        isPaused = false
        guard let url = current?.videoURL else {
            tearDownPlayer()
            return
        }
        if let player {
            player.pause()
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            player.play()
        } else {
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            newPlayer.play()
        }
    }

    private func tearDownPlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func step(_ direction: Int) {
        let next = currentIndex + direction
        guard moments.indices.contains(next) else {
            if next >= moments.count { model.closeViewer() }
            return
        }
        model.viewerMoment = moments[next]
    }

    // MARK: - UI pieces (matching the reel overlay style)

    private func metaPill(_ moment: Moment) -> some View {
        Text("\(moment.timeLabel) · \(moment.placeName)")
            .font(.hl(13))
            .foregroundStyle(HL.ink)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(.white)
                Capsule().strokeBorder(HL.ink, lineWidth: 2)
            }
    }

    private func captionBox(_ text: String) -> some View {
        Text(text)
            .font(.hl(14))
            .foregroundStyle(HL.ink)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(HL.ink, lineWidth: 2)
            }
    }

    private var editButton: some View {
        Button {
            model.editFromViewer()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .bold))
                Text("Edit")
                    .font(.hl(14))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background {
                Capsule().fill(HL.ink.opacity(0.5))
                Capsule().strokeBorder(.white, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lightweight video view (no AVPlayerViewController overhead)

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

// MARK: - Progress bars (isolated so ticking never re-renders the screen)

private struct ViewerProgressBars: View {
    let count: Int
    let currentIndex: Int
    let player: AVPlayer?
    let isPaused: Bool
    let momentID: UUID?
    var onMockFinished: () -> Void

    @State private var progress: Double = 0

    /// Display time for moments that have no recorded clip.
    private let mockDurationSeconds = 5.0
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.3))
                        Capsule().fill(.white)
                            .frame(width: geometry.size.width * fillFraction(for: index))
                    }
                }
                .frame(height: 7)
                .overlay {
                    Capsule().strokeBorder(HL.ink, lineWidth: 1.5)
                }
            }
        }
        .onReceive(ticker) { _ in tick() }
        .onChange(of: momentID) { progress = 0 }
    }

    private func fillFraction(for index: Int) -> CGFloat {
        if index < currentIndex { return 1 }
        if index == currentIndex { return CGFloat(min(max(progress, 0), 1)) }
        return 0
    }

    private func tick() {
        guard !isPaused else { return }
        if let player, let item = player.currentItem {
            let duration = item.duration.seconds
            if duration.isFinite && duration > 0 {
                progress = min(player.currentTime().seconds / duration, 1)
            }
        } else {
            progress += 0.1 / mockDurationSeconds
            if progress >= 1 {
                progress = 0
                onMockFinished()
            }
        }
    }
}
