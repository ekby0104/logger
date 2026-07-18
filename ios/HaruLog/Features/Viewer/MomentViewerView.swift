import AVKit
import SwiftUI
import SwiftData

/// Story-style viewer. Tap left/right halves to move between moments.
/// Plays the recorded clip when the moment has one; shows the mock frame otherwise.
struct MomentViewerView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Moment.createdAt) private var moments: [Moment]
    @State private var player: AVPlayer?

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
                VideoPlayer(player: player)
                    .disabled(true)
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

            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { step(-1) }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { step(1) }
            }

            VStack(alignment: .leading, spacing: 0) {
                progressBars

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

                if let moment = current {
                    info(moment)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .onAppear { updatePlayer() }
        .onChange(of: model.viewerMoment?.id) { updatePlayer() }
    }

    private func updatePlayer() {
        if let url = current?.videoURL {
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            newPlayer.play()
        } else {
            player = nil
        }
    }

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(moments.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index <= currentIndex ? Color.white : .white.opacity(0.3))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(HL.ink, lineWidth: 1.5)
                    }
                    .frame(height: 7)
            }
        }
    }

    private func info(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(moment.timeLabel)
                    .font(.hl(13))
                    .foregroundStyle(.white)
                Text(moment.mood.rawValue)
                    .font(.hl(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background {
                        Capsule().fill(HL.purple)
                        Capsule().strokeBorder(.white, lineWidth: 2)
                    }
            }
            .padding(.bottom, 4)

            Text(moment.title)
                .font(.hl(24))
                .foregroundStyle(.white)

            Text(moment.caption)
                .font(.hlRegular(14))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.bottom, 10)

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .bold))
                    Text(moment.placeName)
                        .font(.hl(13))
                }
                .foregroundStyle(.white)

                Spacer()

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
    }

    private func step(_ direction: Int) {
        let next = currentIndex + direction
        guard moments.indices.contains(next) else {
            if next >= moments.count { model.closeViewer() }
            return
        }
        model.viewerMoment = moments[next]
    }
}
