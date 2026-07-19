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
    @Environment(\.widgetFamily) private var family

    private let ink = Color(red: 0x13 / 255, green: 0x18 / 255, blue: 0x26 / 255)
    private let paper = Color(red: 0xF4 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    private let purple = Color(red: 0xA8 / 255, green: 0x55 / 255, blue: 0xF7 / 255)
    private let gray = Color(red: 0x4F / 255, green: 0x56 / 255, blue: 0x63 / 255)

    /// Follows the app's font choice via the shared app group.
    private func widgetFont(_ size: CGFloat) -> Font {
        let choice = UserDefaults(suiteName: "group.com.dailogger.app")?
            .string(forKey: "appFont") ?? "typewriter"
        switch choice {
        case "kwonjungae":
            // KwonJungae renders small for its point size — boost it.
            return .custom("Together-KwonJungae", size: size * 1.15)
        case "system":
            return .system(size: size, weight: .bold)
        default:
            return .custom("AmericanTypewriter-Bold", size: size)
        }
    }

    var body: some View {
        Group {
            if family == .systemMedium {
                medium
            } else {
                small
            }
        }
        .containerBackground(paper, for: .widget)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(purple)
                Text("Streak")
                    .font(widgetFont(13))
                    .foregroundStyle(gray)
            }

            Text("\(entry.streak)")
                .font(widgetFont(44))
                .foregroundStyle(ink)

            todayLine(size: 11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(purple)
                    Text("Streak")
                        .font(widgetFont(14))
                        .foregroundStyle(gray)
                }
                Text("\(entry.streak)")
                    .font(widgetFont(46))
                    .foregroundStyle(ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(purple)
                    Text("Today")
                        .font(widgetFont(14))
                        .foregroundStyle(gray)
                }
                Text("\(entry.todayCount)")
                    .font(widgetFont(46))
                    .foregroundStyle(ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func todayLine(size: CGFloat) -> some View {
        Group {
            if entry.todayCount == 0 {
                Text("No clips yet today")
            } else {
                Text("\(entry.todayCount) clips today")
            }
        }
        .font(widgetFont(size))
        .foregroundStyle(gray)
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailoggerStreak", provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description(String(localized: "Your recording streak at a glance."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
