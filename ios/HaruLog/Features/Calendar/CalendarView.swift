import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @State private var selectedDay = Calendar.current.component(.day, from: .now)

    private var calendar: Calendar { Calendar.current }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: .now)
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: .now)
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
                    ForEach(Array("SMTWTFS".enumerated()), id: \.offset) { _, letter in
                        Text(String(letter))
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

    private var detailCard: some View {
        let hasBlog = blogDays.contains(selectedDay)
        let meta = hasBlog ? "\(3 + selectedDay % 4) moments · blog ready" : "No records"

        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("\(monthName) \(selectedDay)")
                    .font(.hl(17))
                    .foregroundStyle(HL.ink)
                Spacer()
                Text(meta)
                    .font(.hlRegular(12.5))
                    .foregroundStyle(HL.gray)
            }

            HStack(spacing: 7) {
                ForEach(0..<4) { _ in
                    PlaceholderBox(radius: 10)
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .hardCard(radius: 18)
    }
}
