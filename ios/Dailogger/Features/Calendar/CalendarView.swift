import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query(sort: \Moment.createdAt) private var moments: [Moment]
    @State private var monthOffset = 0
    @State private var selectedDay = Calendar.current.component(.day, from: .now)

    private var calendar: Calendar { Calendar.current }

    private var displayedMonth: Date {
        let components = calendar.dateComponents([.year, .month], from: .now)
        let start = calendar.date(from: components) ?? .now
        return calendar.date(byAdding: .month, value: monthOffset, to: start) ?? start
    }

    private var isCurrentMonth: Bool { monthOffset == 0 }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.year().month(.wide))
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
    }

    private var leadingBlanks: Int {
        calendar.component(.weekday, from: displayedMonth) - 1
    }

    private var blogDays: Set<Int> {
        Set(
            logs.filter {
                calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month)
            }
            .map { calendar.component(.day, from: $0.date) }
        )
    }

    private var todayDay: Int {
        calendar.component(.day, from: .now)
    }

    private var selectedDate: Date {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        let dayComponents = DateComponents(
            year: components.year, month: components.month, day: selectedDay
        )
        return calendar.date(from: dayComponents) ?? displayedMonth
    }

    private var selectedLog: DailyLog? {
        logs.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var selectedDayMoments: [Moment] {
        moments.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
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

                // One ForEach for blanks and days: two ForEach ranges here
                // produced colliding IDs (blank 1,2 vs day 1,2), which makes
                // LazyVGrid drop or misplace cells.
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(0..<(leadingBlanks + daysInMonth), id: \.self) { slot in
                        if slot < leadingBlanks {
                            Color.clear
                                .aspectRatio(0.78, contentMode: .fit)
                        } else {
                            dayCell(slot - leadingBlanks + 1)
                        }
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(monthTitle)
                    .font(.hl(27))
                    .foregroundStyle(HL.ink)
                Text("You logged \(blogDays.count) days this month")
                    .font(.hlRegular(13))
                    .foregroundStyle(HL.gray)
            }

            Spacer()

            HStack(spacing: 10) {
                monthNavButton(systemImage: "chevron.left", disabled: false) {
                    changeMonth(by: -1)
                }
                monthNavButton(systemImage: "chevron.right", disabled: isCurrentMonth) {
                    changeMonth(by: 1)
                }
            }
        }
    }

    private func monthNavButton(
        systemImage: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(disabled ? HL.muted : HL.ink)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .hardCard(radius: 10, shadowOffset: 3)
        .disabled(disabled)
    }

    private func changeMonth(by delta: Int) {
        guard monthOffset + delta <= 0 else { return }
        monthOffset += delta
        if isCurrentMonth {
            selectedDay = todayDay
        } else {
            selectedDay = blogDays.min() ?? 1
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let hasBlog = blogDays.contains(day)
        let isToday = isCurrentMonth && day == todayDay
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

        // Tapping the day header plays it as a story; each thumbnail opens
        // the viewer at that moment, and with more than four moments the
        // strip scrolls horizontally. The "Read the blog" row opens the text.
        return VStack(alignment: .leading, spacing: 13) {
            Button {
                model.openDayStory(for: selectedDate, context: context)
            } label: {
                HStack {
                    Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                        .font(.hl(17))
                        .foregroundStyle(HL.ink)
                    Spacer()
                    Text(meta)
                        .font(.hlRegular(12.5))
                        .foregroundStyle(HL.gray)
                }
            }
            .buttonStyle(.plain)

            thumbnailStrip

            if let log, log.blogText != nil {
                Button {
                    model.openBlog(log)
                } label: {
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
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .hardCard(radius: 18)
    }

    /// Four thumbnails fill the row; more than four scroll horizontally,
    /// snapping per cell. Empty slots keep the four-column rhythm.
    private var thumbnailStrip: some View {
        Group {
            if selectedDayMoments.count > 4 {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(selectedDayMoments) { moment in
                            thumbCell(moment)
                                .containerRelativeFrame(.horizontal, count: 4, spacing: 7)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            } else {
                HStack(spacing: 7) {
                    ForEach(selectedDayMoments) { moment in
                        thumbCell(moment)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(0..<(4 - selectedDayMoments.count), id: \.self) { _ in
                        PlaceholderBox(radius: 10)
                            .aspectRatio(9.0 / 16.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func thumbCell(_ moment: Moment) -> some View {
        Button {
            model.openViewer(moment)
        } label: {
            MomentThumb(moment: moment, radius: 10)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}
