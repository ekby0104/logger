import AVKit
import SwiftUI
import SwiftData
import UIKit

/// Daily blog editor: editable title/body, opt-in AI writing,
/// clip strip, and reel-video creation with app-styled overlays.
/// Text fields use local state so typing stays fast; values sync to the
/// model on save (and from the model after AI generation).
struct DailyBlogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Moment.createdAt) private var moments: [Moment]
    @State private var title = ""
    @State private var bodyText = ""

    private var dateLabel: String {
        model.blogDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// Clips recorded on the blog's day (empty for archived days without media).
    private var dayMoments: [Moment] {
        let calendar = Calendar.current
        return moments.filter { calendar.isDate($0.createdAt, inSameDayAs: model.blogDate) }
    }

    private var shareText: String {
        "\(title)\n\n\(bodyText)\n\n" + String(localized: "— Dailogger, \(dateLabel)")
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(dateLabel)
                        .font(.hlRegular(13))
                        .foregroundStyle(HL.gray)

                    TextField("Give the day a title", text: $title, axis: .vertical)
                        .font(.hl(26))
                        .foregroundStyle(HL.ink)
                        .padding(.top, 4)

                    HStack(spacing: 8) {
                        Text("\(dayMoments.count) moments")
                            .font(.hl(12.5))
                            .foregroundStyle(HL.gray)
                        if model.blogIsAI {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                Text("On-device AI")
                                    .font(.hl(11))
                            }
                            .foregroundStyle(HL.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .overlay {
                                Capsule().strokeBorder(HL.purple, lineWidth: 1.5)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 18)

                    TextField("Write about your day…", text: $bodyText, axis: .vertical)
                        .font(.hlRegular(15))
                        .foregroundStyle(HL.ink)
                        .lineLimit(1...2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .hardCard(radius: 18)
                        .padding(.bottom, 16)

                    aiButton
                        .padding(.bottom, 10)

                    PrimaryButton(title: String(localized: "Save blog"), systemImage: "checkmark") {
                        model.blogTitle = title
                        model.blogBody = bodyText
                        model.saveBlog(context: context)
                    }
                    .padding(.bottom, 24)

                    if !dayMoments.isEmpty {
                        Text("Clips from this day")
                            .font(.hl(16))
                            .foregroundStyle(HL.ink)
                            .padding(.bottom, 10)

                        BlogClipStrip(moments: dayMoments)

                        BlogReelSection(moments: dayMoments, blogText: bodyText)
                            .padding(.top, 24)
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(HL.paper.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            ToastView()
        }
        .onAppear {
            title = model.blogTitle
            bodyText = model.blogBody
        }
        .onChange(of: model.blogTitle) { title = model.blogTitle }
        .onChange(of: model.blogBody) { bodyText = model.blogBody }
    }

    private var header: some View {
        HStack {
            Button {
                model.closeOverlay()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(HL.ink)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Daily Blog")
                .font(.hl(17))
                .foregroundStyle(HL.ink)

            Spacer()

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(HL.ink)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background {
            HL.paper
                .overlay(alignment: .bottom) {
                    Rectangle().fill(HL.ink).frame(height: 2)
                }
        }
    }

    private var aiButton: some View {
        Button {
            model.generateBlogWithAI(context: context)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: model.isWritingBlog ? "hourglass" : "sparkles")
                    .font(.system(size: 15, weight: .bold))
                if model.isWritingBlog {
                    Text("Writing your day…")
                        .font(.hl(15))
                } else {
                    Text("Write with AI")
                        .font(.hl(15))
                }
            }
            .foregroundStyle(HL.purple)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(HL.purple, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(model.isWritingBlog)
        .opacity(model.isWritingBlog ? 0.7 : 1)
    }
}

// MARK: - Clip strip (separate view so typing doesn't re-diff the thumbnails)

private struct BlogClipStrip: View {
    let moments: [Moment]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(moments) { moment in
                    VStack(spacing: 4) {
                        MomentThumb(moment: moment, radius: 10)
                            .frame(width: 64, height: 90)
                        Text(moment.timeLabel)
                            .font(.hl(10))
                            .foregroundStyle(HL.gray)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Reel creation/sharing

private struct BlogReelSection: View {
    @Environment(AppModel.self) private var model
    let moments: [Moment]
    let blogText: String

    @State private var reelURL: URL?
    @State private var isMakingReel = false
    @State private var showPreview = false

    private var clipURLs: [URL] {
        moments.compactMap(\.videoURL)
    }

    var body: some View {
        Group {
            if !clipURLs.isEmpty {
                if let reelURL {
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            Button {
                                showPreview = true
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Preview reel")
                                        .font(.hl(15))
                                }
                                .foregroundStyle(HL.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }
                            .buttonStyle(.plain)
                            .hardCard(radius: 12, shadowOffset: 4)

                            ShareLink(item: reelURL) {
                                HStack(spacing: 7) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Share")
                                        .font(.hl(15))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }
                            .buttonStyle(.plain)
                            .hardCard(fill: HL.purple, radius: 12, shadowOffset: 4)
                        }

                        Button {
                            self.reelURL = nil
                        } label: {
                            Text("Make another style")
                                .font(.hl(13))
                                .foregroundStyle(HL.purple)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .sheet(isPresented: $showPreview) {
                        ReelPreviewSheet(url: reelURL)
                    }
                } else if isMakingReel {
                    PrimaryButton(
                        title: String(localized: "Making the reel…"),
                        systemImage: "hourglass",
                        height: 50
                    ) {}
                    .disabled(true)
                    .opacity(0.7)
                } else {
                    VStack(spacing: 14) {
                        PrimaryButton(
                            title: String(localized: "Create timeline reel"),
                            systemImage: "list.bullet.rectangle",
                            height: 50
                        ) {
                            makeReel(style: .timeline)
                        }

                        Button {
                            makeReel(style: .fullscreen)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "rectangle.portrait.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Create full-size reel")
                                    .font(.hl(16))
                            }
                            .foregroundStyle(HL.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.plain)
                        .hardCard(radius: 12, shadowOffset: 4)
                    }
                }
            }
        }
        // The overlays bake in the blog text, so a text change invalidates the reel.
        .onChange(of: blogText) { reelURL = nil }
    }

    private func makeReel(style: ReelStyle) {
        guard !isMakingReel else { return }
        isMakingReel = true
        let reelMoments = moments.filter { $0.videoURL != nil }
        let text = blogText
        Task { @MainActor in
            do {
                reelURL = try await ReelComposer.makeReel(
                    moments: reelMoments, blogText: text, style: style
                )
            } catch {
                model.flashToast(String(localized: "Couldn't make the reel"))
            }
            isMakingReel = false
        }
    }
}

// MARK: - Reel preview player

private struct ReelPreviewSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(HL.ink)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Preview reel")
                    .font(.hl(17))
                    .foregroundStyle(HL.ink)

                Spacer()

                Color.clear.frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background {
                HL.paper
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(HL.ink).frame(height: 2)
                    }
            }

            if let player {
                VideoPlayer(player: player)
                    .background(HL.camBackground)
            } else {
                HL.camBackground
            }
        }
        .background(HL.camBackground.ignoresSafeArea())
        .onAppear {
            PlaybackAudio.activate()
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            newPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
