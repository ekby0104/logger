import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Moment.createdAt) private var allMoments: [Moment]

    /// Every recorded day, newest day first; moments inside a day stay in
    /// time order so each day reads top-to-bottom like a diary entry.
    private var days: [(date: Date, moments: [Moment])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allMoments) {
            calendar.startOfDay(for: $0.createdAt)
        }
        return grouped.keys.sorted(by: >).map { date in
            (date: date, moments: grouped[date] ?? [])
        }
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return String(localized: "Today")
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Timeline")
                    .font(.hl(27))
                    .foregroundStyle(HL.ink)
                Text("\(allMoments.count) moments")
                    .font(.hlRegular(13))
                    .foregroundStyle(HL.gray)
                    .padding(.top, 3)
                    .padding(.bottom, 22)

                if allMoments.isEmpty {
                    EmptyMomentsCard()
                } else {
                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(days, id: \.date) { day in
                            VStack(alignment: .leading, spacing: 14) {
                                dayHeader(day.date)

                                ZStack(alignment: .topLeading) {
                                    VerticalDashedLine()
                                        .padding(.leading, 46)
                                        .padding(.vertical, 8)

                                    VStack(spacing: 20) {
                                        ForEach(day.moments) { moment in
                                            TimelineEntry(moment: moment)
                                        }
                                    }
                                }
                            }
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

    private func dayHeader(_ date: Date) -> some View {
        Text(dayTitle(date))
            .font(.hl(13))
            .foregroundStyle(HL.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule().fill(.white)
                Capsule().strokeBorder(HL.ink, lineWidth: 2)
            }
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
    @Environment(\.modelContext) private var context
    let moment: Moment

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(moment.timeLabel)
                .font(.hl(12))
                .foregroundStyle(HL.gray)
                .frame(width: 40, alignment: .trailing)
                .padding(.top, 4)

            // Dot spans x 40-54 so its center (47) sits exactly on the
            // dashed rail (leading 46 + width 2), slightly below the card top.
            Circle()
                .fill(HL.purple)
                .overlay {
                    Circle().strokeBorder(HL.ink, lineWidth: 2)
                }
                .frame(width: 14, height: 14)
                .padding(.top, 8)
                .padding(.trailing, 10)

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

                Text(moment.caption)
                    .font(.hl(15))
                    .foregroundStyle(HL.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 14, trailing: 14))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .hardCard(radius: 16)
        .contextMenu {
            Button(role: .destructive) {
                model.deleteMoment(moment, context: context)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
