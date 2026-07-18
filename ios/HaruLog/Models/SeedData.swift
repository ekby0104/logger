import Foundation
import SwiftData

/// Inserts wireframe mock data on first launch so every screen has content.
enum SeedData {
    static func insertIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Moment>())) ?? 0
        guard count == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }

        let moments: [Moment] = [
            Moment(createdAt: at(7, 20), title: "Morning Run",
                   caption: "Opened the day with a run by the sunrise river.",
                   mood: .fresh, duration: 18, placeName: "Ttukseom, Han River"),
            Moment(createdAt: at(9, 5), title: "Morning Coffee",
                   caption: "A warm latte to get things started.",
                   mood: .calm, duration: 12, placeName: "Onion Seongsu"),
            Moment(createdAt: at(12, 40), title: "Lunch Pasta",
                   caption: "Vongole with coworkers — best meal today.",
                   mood: .happy, duration: 25, placeName: "Euljiro Alley"),
            Moment(createdAt: at(15, 30), title: "Afternoon Walk",
                   caption: "Afternoon light seeping through the trees.",
                   mood: .peaceful, duration: 20, placeName: "Seoul Forest"),
            Moment(createdAt: at(19, 15), title: "Evening Glow",
                   caption: "A red sky spreading over the city.",
                   mood: .moved, duration: 30, placeName: "Namsan Deck"),
            Moment(createdAt: at(22, 0), title: "Winding Down",
                   caption: "Made it through today. Goodnight.",
                   mood: .proud, duration: 15, placeName: "Home")
        ]
        moments.forEach { context.insert($0) }

        let components = calendar.dateComponents([.year, .month, .day], from: today)
        let todayDay = components.day ?? 1
        var blogDays = Set([1, 2, 3, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18].filter { $0 <= todayDay })
        blogDays.insert(todayDay)

        for day in blogDays.sorted() {
            let dayComponents = DateComponents(year: components.year, month: components.month, day: day)
            if let date = calendar.date(from: dayComponents) {
                context.insert(DailyLog(date: date, clipCount: 2 + day % 5))
            }
        }
    }
}
