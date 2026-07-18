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
}
