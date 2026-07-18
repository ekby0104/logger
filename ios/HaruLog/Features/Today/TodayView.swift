import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Moment.createdAt) private var moments: [Moment]

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: .now)
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

                    ForEach(moments) { moment in
                        MomentRow(moment: moment)
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
            StreakPill(days: 12)
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
                ForEach(0..<6) { _ in
                    PlaceholderBox(radius: 9)
                        .frame(height: 54)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 16)

            PrimaryButton(title: "Create daily blog", systemImage: "sparkles") {
                model.makeBlog()
            }
        }
        .padding(20)
        .hardCard(radius: 20)
    }
}

struct MomentRow: View {
    @Environment(AppModel.self) private var model
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
                    HStack(spacing: 6) {
                        Text(moment.timeLabel)
                            .font(.hl(12))
                            .foregroundStyle(HL.gray)
                        MoodPill(mood: moment.mood)
                    }
                    Text(moment.title)
                        .font(.hl(16))
                        .foregroundStyle(HL.ink)
                        .lineLimit(1)
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
    }
}
