import Foundation
import WidgetKit

/// Publishes streak/today-count into the shared app group and asks the
/// home-screen widget to refresh.
enum WidgetBridge {
    static let suiteName = "group.com.dailogger.app"

    static func update(streak: Int, todayCount: Int) {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(streak, forKey: "widget.streak")
        defaults?.set(todayCount, forKey: "widget.todayCount")
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Mirrors the app-font choice into the app group so the widget
    /// renders with the same typeface.
    static func syncFontChoice(_ raw: String) {
        UserDefaults(suiteName: suiteName)?.set(raw, forKey: HLFontChoice.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
