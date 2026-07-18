import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @Query private var moments: [Moment]

    private let archiveColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 22)

                statsCard
                    .padding(.bottom, 24)

                HStack {
                    Text("Past daily blogs")
                        .font(.hl(16))
                        .foregroundStyle(HL.ink)
                    Spacer()
                    Text("\(logs.count) total")
                        .font(.hl(12.5))
                        .foregroundStyle(HL.gray)
                }
                .padding(.bottom, 12)

                LazyVGrid(columns: archiveColumns, spacing: 8) {
                    ForEach(logs) { log in
                        archiveCell(log)
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
        HStack(spacing: 14) {
            Circle()
                .fill(HL.placeholder)
                .overlay {
                    Circle().strokeBorder(HL.ink, lineWidth: 2)
                }
                .overlay {
                    Image(systemName: "person")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(HL.ink)
                }
                .frame(width: 64, height: 64)
                .background {
                    Circle().fill(HL.ink).offset(x: 3, y: 3)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("Jiwoo's Days")
                    .font(.hl(19))
                    .foregroundStyle(HL.ink)
                Text("@jiwoo.daily")
                    .font(.hlRegular(13))
                    .foregroundStyle(HL.gray)
            }

            Spacer()

            Button {
                // Settings: 2차 릴리즈
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HL.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .hardCard(radius: 12, shadowOffset: 3)
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: "12", label: "Streak")
            statItem(value: "\(logs.count)", label: "Blogs")
            statItem(value: "\(moments.count)", label: "Moments")
        }
        .padding(.vertical, 16)
        .hardCard(radius: 16)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.hl(23))
                .foregroundStyle(HL.ink)
            Text(label)
                .font(.hlRegular(12))
                .foregroundStyle(HL.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func archiveCell(_ log: DailyLog) -> some View {
        Button {
            model.openBlog(log)
        } label: {
            archiveCellContent(log)
        }
        .buttonStyle(.plain)
    }

    private func archiveCellContent(_ log: DailyLog) -> some View {
        PlaceholderBox(radius: 12)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                Text(log.dayLabel)
                    .font(.hl(12))
                    .foregroundStyle(HL.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.white)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(HL.ink, lineWidth: 1.5)
                    }
                    .padding(6)
            }
            .overlay(alignment: .topTrailing) {
                Text("\(log.clipCount) clips")
                    .font(.hl(10))
                    .foregroundStyle(HL.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.white)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(HL.ink, lineWidth: 1.5)
                    }
                    .padding(6)
            }
    }
}
