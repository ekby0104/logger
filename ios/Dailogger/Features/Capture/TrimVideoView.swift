import AVFoundation
import AVKit
import SwiftUI

/// Shown when an imported video is longer than the clip limit: previews the
/// video, lets the user slide a 5-second window, and exports just that part.
struct TrimVideoView: View {
    @Environment(AppModel.self) private var model

    @State private var player: AVPlayer?
    @State private var duration: Double = 0
    @State private var start: Double = 0

    private let windowSeconds = Double(AppModel.maxClipSeconds)
    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var maxStart: Double { max(duration - windowSeconds, 0) }

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                HL.camBackground
                if let player {
                    VideoPlayer(player: player)
                        .disabled(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(HL.ink, lineWidth: 2)
            }
            .padding(18)

            controls
        }
        .background(HL.paper.ignoresSafeArea())
        .task { await load() }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onReceive(ticker) { _ in loopInsideWindow() }
        .onChange(of: start) {
            seekToStart()
        }
    }

    private var header: some View {
        HStack {
            Button {
                model.cancelTrim()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HL.ink)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Trim to 5 seconds")
                .font(.hl(17))
                .foregroundStyle(HL.ink)

            Spacer()

            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            HL.paper
                .overlay(alignment: .bottom) {
                    Rectangle().fill(HL.ink).frame(height: 2)
                }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep 5 seconds starting at \(timeString(start))")
                .font(.hl(14))
                .foregroundStyle(HL.ink)

            if maxStart > 0 {
                Slider(value: $start, in: 0...maxStart)
                    .tint(HL.blue)
            }

            HStack {
                Text(timeString(start))
                Spacer()
                Text(timeString(min(start + windowSeconds, duration)))
            }
            .font(.hlRegular(12.5))
            .foregroundStyle(HL.gray)

            PrimaryButton(
                title: String(localized: "Use this part"),
                systemImage: "checkmark",
                height: 54
            ) {
                model.confirmTrim(start: start)
            }
            .disabled(model.isImporting)
            .opacity(model.isImporting ? 0.6 : 1)
            .padding(.top, 8)
        }
        .padding(18)
        .padding(.bottom, 24)
    }

    // MARK: - Playback

    private func load() async {
        guard let url = model.trimVideoURL else { return }
        let asset = AVURLAsset(url: url)
        if let loaded = try? await asset.load(.duration), loaded.seconds.isFinite {
            duration = loaded.seconds
        }
        PlaybackAudio.activate()
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = false
        player = newPlayer
        newPlayer.play()
    }

    /// Keeps playback inside the selected 5-second window.
    private func loopInsideWindow() {
        guard let player else { return }
        let time = player.currentTime().seconds
        if time >= start + windowSeconds || time < start - 0.3 {
            seekToStart()
        }
    }

    private func seekToStart() {
        player?.seek(
            to: CMTime(seconds: start, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        player?.play()
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
