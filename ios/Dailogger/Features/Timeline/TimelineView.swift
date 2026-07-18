import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Moment.createdAt) private var moments: [Moment]

    private var dateLabel: String {
        Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Timeline")
                    .font(.hl(27))
                    .foregroundStyle(HL.ink)
                Text("\(dateLabel) · \(moments.count) moments")
                    .font(.hlRegular(13))
                    .foregroundStyle(HL.gray)
                    .padding(.top, 3)
                    .padding(.bottom, 22)

                ZStack(alignment: .topLeading) {
                    VerticalDashedLine()
                        .padding(.leading, 46)
                        .padding(.vertical, 8)

                    VStack(spacing: 20) {
                        ForEach(moments) { moment in
                            TimelineEntry(moment: moment)
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
}

private struct VerticalDashedLine: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 1, y: 0))
                path.addLine(to: CGPoint(x: 1, y: geometry.size.height))
            }
            .stroke(HL.ink, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
        }
        .frame(width: 2)
    }
}

private struct TimelineEntry: View {
    @Environment(AppModel.self) private var model
    let moment: Moment

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(moment.timeLabel)
                .font(.hl(12))
                .foregroundStyle(HL.gray)
                .frame(width: 40, alignment: .trailing)
                .padding(.top, 2)

            Circle()
                .fill(HL.purple)
                .overlay {
                    Circle().strokeBorder(HL.ink, lineWidth: 2)
                }
                .frame(width: 14, height: 14)
                .padding(.top, 4)
                .padding(.horizontal, 5)

            card
        }
    }

    private var card: some View {
        Button {
            model.openViewer(moment)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                MomentThumb(moment: moment, radius: 0)
                    .frame(height: 150)
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.white)
                                .overlay {
                                    Circle().strokeBorder(HL.ink, lineWidth: 2)
                                }
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(HL.ink)
                                }
                            DurBadge(text: moment.durationLabel)
                        }
                        .padding(10)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(moment.title)
                            .font(.hl(16))
                            .foregroundStyle(HL.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        MoodPill(mood: moment.mood)
                    }
                    Text(moment.caption)
                        .font(.hlRegular(13))
                        .foregroundStyle(HL.gray)
                        .multilineTextAlignment(.leading)
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 14, trailing: 14))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .hardCard(radius: 16)
    }
}
