import Foundation
import WidgetKit

/// Publishes streak/today-count into the shared app group and asks the
/// home-screen widget to refresh.
enum WidgetBridge {
    static let suiteName = "group.com.dailogger.app"

    struct StatsSnapshot {
        let streak: Int
        let todayCount: Int
        let calculatedDay: Date
        let lastActiveDay: Date?
    }

    private static let streakKey = "widget.streak"
    private static let todayCountKey = "widget.todayCount"
    private static let calculatedDayKey = "widget.statsCalculatedDay"
    private static let lastActiveDayKey = "widget.statsLastActiveDay"

    static func statsSnapshot() -> StatsSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let calculatedDay = defaults.object(forKey: calculatedDayKey) as? Date
        else { return nil }

        let lastActiveDay = defaults.object(forKey: lastActiveDayKey) as? Date
        return StatsSnapshot(
            streak: defaults.integer(forKey: streakKey),
            todayCount: defaults.integer(forKey: todayCountKey),
            calculatedDay: calculatedDay,
            lastActiveDay: lastActiveDay
        )
    }

    static func update(streak: Int, todayCount: Int, lastActiveDay: Date?) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        let hasPublishedValues = defaults.object(forKey: streakKey) != nil &&
            defaults.object(forKey: todayCountKey) != nil
        let valuesChanged = !hasPublishedValues ||
            defaults.integer(forKey: streakKey) != streak ||
            defaults.integer(forKey: todayCountKey) != todayCount
        defaults.set(streak, forKey: streakKey)
        defaults.set(todayCount, forKey: todayCountKey)
        defaults.set(Calendar.current.startOfDay(for: .now), forKey: calculatedDayKey)
        defaults.set(lastActiveDay, forKey: lastActiveDayKey)

        // WidgetKit keeps the existing timeline when only bookkeeping dates
        // change; reloading it on every app launch is needless work.
        if valuesChanged {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Mirrors the app-font choice into the app group so the widget
    /// renders with the same typeface.
    static func syncFontChoice(_ raw: String) {
        UserDefaults(suiteName: suiteName)?.set(raw, forKey: HLFontChoice.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
