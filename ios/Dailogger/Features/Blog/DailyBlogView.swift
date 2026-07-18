import SwiftUI
import SwiftData

/// Full-screen daily blog: generated title + diary body + today's clip strip.
struct DailyBlogView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Moment.createdAt) private var moments: [Moment]
    @State private var reelURL: URL?
    @State private var isMakingReel = false

    private var dateLabel: String {
        model.blogDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// Clips recorded on the blog's day (empty for archived days without media).
    private var dayMoments: [Moment] {
        let calendar = Calendar.current
        return moments.filter { calendar.isDate($0.createdAt, inSameDayAs: model.blogDate) }
    }

    private var shareText: String {
        "\(model.blogTitle)\n\n\(model.blogBody)\n\n" + String(localized: "— Dailogger, \(dateLabel)")
    }

    private var clipURLs: [URL] {
        dayMoments.compactMap(\.videoURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(dateLabel)
                        .font(.hlRegular(13))
                        .foregroundStyle(HL.gray)

                    Text(model.blogTitle)
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

                    Text(model.blogBody)
                        .font(.hlRegular(15))
                        .foregroundStyle(HL.ink)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .hardCard(radius: 18)
                        .padding(.bottom, 24)

                    if !dayMoments.isEmpty {
                        Text("Clips from this day")
                            .font(.hl(16))
                            .foregroundStyle(HL.ink)
                            .padding(.bottom, 10)

                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(dayMoments) { moment in
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

                        reelSection
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
    }

    /// Merges the day's clips into a single video and offers it for sharing.
    @ViewBuilder
    private var reelSection: some View {
        if !clipURLs.isEmpty {
            if let reelURL {
                ShareLink(item: reelURL) {
                    HStack(spacing: 7) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                        Text("Share reel video")
                            .font(.hl(16))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .hardCard(fill: HL.purple, radius: 12, shadowOffset: 4)
            } else {
                PrimaryButton(
                    title: isMakingReel
                        ? String(localized: "Making the reel…")
                        : String(localized: "Create reel video"),
                    systemImage: isMakingReel ? "hourglass" : "film",
                    height: 50
                ) {
                    makeReel()
                }
                .disabled(isMakingReel)
                .opacity(isMakingReel ? 0.7 : 1)
            }
        }
    }

    private func makeReel() {
        guard !isMakingReel else { return }
        isMakingReel = true
        let urls = clipURLs
        Task { @MainActor in
            do {
                reelURL = try await VideoComposer.merge(segmentURLs: urls)
            } catch {
                model.flashToast(String(localized: "Couldn't make the reel"))
            }
            isMakingReel = false
        }
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
}
