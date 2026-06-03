import Foundation
import UserNotifications

/// Schedules a weekly recap reminder (default Sunday 6pm). Local notification; reuses the
/// launch-time authorization. Deep-links into the weekly review.
enum WeeklyReviewNotifications {
    static let identifier = "tempo.weekly.review"
    static let deepLinkID = "weeklyReview"

    enum Defaults {
        static let enabled = "weekly.enabled"
        static let weekday = "weekly.weekday"   // 1 = Sunday (Gregorian)
        static let hour = "weekly.hour"
        static let minute = "weekly.minute"
    }

    static func reschedule(enabled: Bool, weekday: Int, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your week in review"
        content.body = "See how your week went and what stood out."
        content.userInfo = ["deepLink": deepLinkID]

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func rescheduleFromDefaults(_ defaults: UserDefaults = .standard) {
        let enabled = defaults.object(forKey: Defaults.enabled) as? Bool ?? false
        let weekday = defaults.object(forKey: Defaults.weekday) as? Int ?? 1
        let hour = defaults.object(forKey: Defaults.hour) as? Int ?? 18
        let minute = defaults.object(forKey: Defaults.minute) as? Int ?? 0
        reschedule(enabled: enabled, weekday: weekday, hour: hour, minute: minute)
    }
}
