import Foundation
import UserNotifications

/// Daily "record your day" reminder at 21:00.
/// Keeps up to three one-shot notifications scheduled (today if nothing has
/// been recorded yet, plus the next two days); every app launch or save
/// reschedules them, so today's reminder disappears once a moment exists.
enum ReminderService {
    static let enabledKey = "reminderEnabled"
    private static let hour = 21
    private static let idPrefix = "daily-reminder-"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    static func reschedule(hasMomentToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: (0...2).map { idPrefix + "\($0)" }
        )
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }

        let calendar = Calendar.current
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Dailogger")
        content.body = String(localized: "How was your day? Capture a moment 📹")
        content.sound = .default

        for offset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: .now) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            guard let fireDate = calendar.date(from: components) else { continue }
            if offset == 0 && (hasMomentToday || fireDate <= .now) { continue }

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour], from: fireDate),
                repeats: false
            )
            center.add(UNNotificationRequest(
                identifier: idPrefix + "\(offset)",
                content: content,
                trigger: trigger
            ))
        }
    }
}
