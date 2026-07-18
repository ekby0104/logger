import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query(sort: \Moment.createdAt) private var moments: [Moment]
    @State private var selectedDay = Calendar.current.component(.day, from: .now)

    private var calendar: Calendar { Calendar.current }

    private var monthTitle: String {
        Date.now.formatted(.dateTime.year().month(.wide))
    }

    private var selectedDate: Date {
        let components = calendar.dateComponents([.year, .month], from: .now)
        let dayComponents = DateComponents(
            year: components.year, month: components.month, day: selectedDay
        )
        return calendar.date(from: dayComponents) ?? .now
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: .now)?.count ?? 30
    }

    private var leadingBlanks: Int {
        let components = calendar.dateComponents([.year, .month], from: .now)
        let firstOfMonth = calendar.date(from: components) ?? .now
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }

    private var blogDays: Set<Int> {
        Set(logs.map { calendar.component(.day, from: $0.date) })
    }

    private var todayDay: Int {
        calendar.component(.day, from: .now)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(monthTitle)
                    .font(.hl(27))
                    .foregroundStyle(HL.ink)
                Text("You logged \(blogDays.count) days this month")
                    .font(.hlRegular(13))
                    .foregroundStyle(HL.gray)
                    .padding(.top, 3)
                    .padding(.bottom, 20)

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.hl(11))
                            .foregroundStyle(HL.gray)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 8)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(0..<leadingBlanks, id: \.self) { _ in
                        Color.clear
                            .aspectRatio(0.78, contentMode: .fit)
                    }
                    ForEach(Array(1...daysInMonth), id: \.self) { day in
                        dayCell(day)
                    }
                }

                detailCard
                    .padding(.top, 22)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    private func dayCell(_ day: Int) -> some View {
        let hasBlog = blogDays.contains(day)
        let isToday = day == todayDay
        let isSelected = day == selectedDay

        return Button {
            if hasBlog { selectedDay = day }
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? HL.blue : (hasBlog ? Color.white : HL.calEmpty))
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isToday && !isSelected ? HL.blue : HL.ink, lineWidth: 2)
                Text("\(day)")
                    .font(.hl(12))
                    .foregroundStyle(isSelected ? .white : (hasBlog ? HL.ink : HL.muted))
                    .padding(5)
                if hasBlog {
                    Circle()
                        .fill(isSelected ? Color.white : HL.purple)
                        .overlay {
                            Circle().strokeBorder(HL.ink, lineWidth: 1.5)
                        }
                        .frame(width: 8, height: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(5)
                }
            }
            .aspectRatio(0.78, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    private var selectedLog: DailyLog? {
        logs.first { calendar.component(.day, from: $0.date) == selectedDay }
    }

    private var selectedDayMoments: [Moment] {
        moments.filter {
            calendar.component(.day, from: $0.createdAt) == selectedDay
                && calendar.isDate($0.createdAt, equalTo: .now, toGranularity: .month)
        }
    }

    private var detailCard: some View {
        let log = selectedLog
        let meta: String
        if let log {
            meta = log.blogText != nil
                ? String(localized: "\(log.clipCount) clips · blog ready")
                : String(localized: "\(log.clipCount) clips · no blog yet")
        } else {
            meta = String(localized: "No records")
        }

        return Button {
            if let log { model.openBlog(log) }
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                        .font(.hl(17))
                        .foregroundStyle(HL.ink)
                    Spacer()
                    Text(meta)
                        .font(.hlRegular(12.5))
                        .foregroundStyle(HL.gray)
                }

                HStack(spacing: 7) {
                    ForEach(Array(selectedDayMoments.prefix(4))) { moment in
                        MomentThumb(moment: moment, radius: 10)
                            .aspectRatio(9.0 / 16.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                    if selectedDayMoments.count < 4 {
                        ForEach(0..<(4 - min(selectedDayMoments.count, 4)), id: \.self) { _ in
                            PlaceholderBox(radius: 10)
                                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                if let log, log.blogText != nil {
                    HStack(spacing: 5) {
                        Image(systemName: "book")
                            .font(.system(size: 12, weight: .bold))
                        Text("Read the blog")
                            .font(.hl(13))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(HL.blue)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .hardCard(radius: 18)
    }
}
