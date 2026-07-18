import Foundation

enum Stats {
    /// Consecutive recorded days ending today (or yesterday, if today has
    /// nothing yet — an unfinished today shouldn't break the streak).
    static func streak(recordDates: [Date], calendar: Calendar = .current) -> Int {
        let days = Set(recordDates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: .now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }
}
