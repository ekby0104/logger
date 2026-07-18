import SwiftUI
import WidgetKit

/// Home-screen widget showing the recording streak and today's clip count,
/// fed via the shared app group by the main app.
struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayCount: Int
}

struct StreakProvider: TimelineProvider {
    private func load() -> StreakEntry {
        let defaults = UserDefaults(suiteName: "group.com.dailogger.app")
        return StreakEntry(
            date: .now,
            streak: defaults?.integer(forKey: "widget.streak") ?? 0,
            todayCount: defaults?.integer(forKey: "widget.todayCount") ?? 0
        )
    }

    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streak: 7, todayCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        // The app pushes fresh data via WidgetCenter; refresh after midnight
        // regardless so the streak display never goes stale by a day.
        let calendar = Calendar.current
        let midnight = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)
        ) ?? .now
        completion(Timeline(entries: [load()], policy: .after(midnight)))
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry

    private let ink = Color(red: 0x13 / 255, green: 0x18 / 255, blue: 0x26 / 255)
    private let paper = Color(red: 0xF4 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    private let purple = Color(red: 0xA8 / 255, green: 0x55 / 255, blue: 0xF7 / 255)
    private let gray = Color(red: 0x4F / 255, green: 0x56 / 255, blue: 0x63 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(purple)
                Text("Streak")
                    .font(.custom("Gaegu-Bold", size: 13))
                    .foregroundStyle(gray)
            }

            Text("\(entry.streak)")
                .font(.custom("Gaegu-Bold", size: 44))
                .foregroundStyle(ink)

            if entry.todayCount == 0 {
                Text("No clips yet today")
                    .font(.custom("Gaegu-Bold", size: 11))
                    .foregroundStyle(gray)
            } else {
                Text("\(entry.todayCount) clips today")
                    .font(.custom("Gaegu-Bold", size: 11))
                    .foregroundStyle(gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(paper, for: .widget)
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailoggerStreak", provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description(String(localized: "Your recording streak at a glance."))
        .supportedFamilies([.systemSmall])
    }
}
