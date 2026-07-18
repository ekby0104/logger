import SwiftUI
import SwiftData

/// Full-screen daily blog: generated title + diary body + today's clip strip.
struct DailyBlogView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Moment.createdAt) private var moments: [Moment]

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: model.blogDate)
    }

    /// Clips recorded on the blog's day (empty for archived days without media).
    private var dayMoments: [Moment] {
        let calendar = Calendar.current
        return moments.filter { calendar.isDate($0.createdAt, inSameDayAs: model.blogDate) }
    }

    private var shareText: String {
        "\(model.blogTitle)\n\n\(model.blogBody)\n\n— HaruLog, \(dateLabel)"
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
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(HL.paper.ignoresSafeArea())
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
