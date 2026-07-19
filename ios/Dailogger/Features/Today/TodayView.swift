import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Moment.createdAt) private var allMoments: [Moment]
    @Query private var logs: [DailyLog]

    /// The Today tab only ever shows today's recordings; the full set is
    /// still needed for the streak, so filtering happens here rather than
    /// in the query (a query predicate would also go stale at midnight).
    private var moments: [Moment] {
        allMoments.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var streak: Int {
        Stats.streak(recordDates: logs.map(\.date) + allMoments.map(\.createdAt))
    }

    private var dateLabel: String {
        Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var totalDurationLabel: String {
        let total = Int(moments.reduce(0) { $0 + $1.duration })
        return "\(total / 60)m \(total % 60)s"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                heroCard

                VStack(alignment: .leading, spacing: 13) {
                    Text("Moments")
                        .font(.hl(16))
                        .foregroundStyle(HL.ink)

                    if moments.isEmpty {
                        EmptyMomentsCard()
                    } else {
                        ForEach(moments) { moment in
                            MomentRow(moment: moment)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(.hlRegular(13))
                    .foregroundStyle(HL.gray)
                Text("Today")
                    .font(.hl(27))
                    .foregroundStyle(HL.ink)
            }
            Spacer()
            StreakPill(days: streak)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Moments today")
                .font(.hlRegular(13))
                .foregroundStyle(HL.gray)

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(moments.count)")
                    .font(.hl(38))
                    .foregroundStyle(HL.ink)
                Text("clips · \(totalDurationLabel)")
                    .font(.hl(15))
                    .foregroundStyle(HL.gray)
            }
            .padding(.top, 2)
            .padding(.bottom, 15)

            HStack(spacing: 6) {
                ForEach(Array(moments.prefix(6))) { moment in
                    MomentThumb(moment: moment, radius: 9)
                        .frame(height: 54)
                        .frame(maxWidth: .infinity)
                }
                if moments.count < 6 {
                    ForEach(0..<(6 - min(moments.count, 6)), id: \.self) { _ in
                        PlaceholderBox(radius: 9)
                            .frame(height: 54)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.bottom, 16)

            PrimaryButton(title: String(localized: "Create daily blog"), systemImage: "sparkles") {
                model.openBlogEditor(context: context)
            }
        }
        .padding(20)
        .hardCard(radius: 20)
    }
}

struct MomentRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    let moment: Moment

    var body: some View {
        Button {
            model.openViewer(moment)
        } label: {
            HStack(spacing: 12) {
                MomentThumb(moment: moment, radius: 11)
                    .frame(width: 70, height: 98)
                    .overlay(alignment: .bottomLeading) {
                        DurBadge(text: moment.durationLabel)
                            .padding(5)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(moment.timeLabel)
                        .font(.hl(12))
                        .foregroundStyle(HL.gray)
                    Text(moment.caption)
                        .font(.hl(15))
                        .foregroundStyle(HL.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .bold))
                        Text(moment.placeName)
                            .font(.hlRegular(12.5))
                    }
                    .foregroundStyle(HL.gray)
                }
                .padding(.top, 3)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(HL.ink)
            }
            .padding(10)
        }
        .buttonStyle(.plain)
        .hardCard(radius: 16, shadowOffset: 3)
        .contextMenu {
            Button(role: .destructive) {
                model.deleteMoment(moment, context: context)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
