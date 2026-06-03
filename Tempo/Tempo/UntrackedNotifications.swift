import Foundation
import UserNotifications

/// Schedules an end-of-day reminder to review untracked time. Local notification only;
/// reuses the authorization already requested at launch. Deep-links into the Day Review.
enum UntrackedNotifications {
    static let identifier = "tempo.untracked.daily"
    static let deepLinkID = "dayReview"

    enum Defaults {
        static let enabled = "untracked.enabled"
        static let hour = "untracked.hour"
        static let minute = "untracked.minute"
    }

    /// (Re)schedule the daily reminder. Pass `enabled: false` to cancel it.
    static func reschedule(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Wrap up your day"
        content.body = "Review and fill in any untracked time."
        content.userInfo = ["deepLink": deepLinkID]

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// Read stored preferences (default: off, 9:00pm) and (re)schedule.
    static func rescheduleFromDefaults(_ defaults: UserDefaults = .standard) {
        let enabled = defaults.object(forKey: Defaults.enabled) as? Bool ?? false
        let hour = defaults.object(forKey: Defaults.hour) as? Int ?? 21
        let minute = defaults.object(forKey: Defaults.minute) as? Int ?? 0
        reschedule(enabled: enabled, hour: hour, minute: minute)
    }
}
