import Foundation
import UserNotifications

/// Schedules the nightly "How was your day?" reminder. Uses local notifications only —
/// no special entitlement, works on a free Apple ID. The reminder repeats daily at the
/// user's chosen time and deep-links into the reflection screen when tapped.
enum ReflectionNotifications {
    static let identifier = "tempo.reflection.daily"
    static let deepLinkID = "reflection"   // matched in the tap handler to route into the screen

    // Preference keys (shared with the `@AppStorage` bindings in SettingsView).
    enum Defaults {
        static let enabled = "reflection.enabled"
        static let hour = "reflection.hour"
        static let minute = "reflection.minute"
    }

    /// Request notification permission, ignoring the result. Called once at launch.
    static func requestAuthorization() async {
        _ = await requestAuthorizationGranted()
    }

    /// Request permission and report whether the user granted it. Used by Settings so the
    /// reminder toggle can react to a denial instead of silently scheduling nothing.
    @discardableResult
    static func requestAuthorizationGranted() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// The current OS-level permission state, so Settings can tell the user when a reminder
    /// won't actually be delivered.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// (Re)schedule the daily reminder. Pass `enabled: false` to cancel it.
    static func reschedule(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "How was your day?"
        content.body = "Take 30 seconds to reflect on today."
        content.userInfo = ["deepLink": deepLinkID]

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// Read the stored preferences (defaults: enabled, 8:00pm) and (re)schedule accordingly.
    static func rescheduleFromDefaults(_ defaults: UserDefaults = .standard) {
        let enabled = defaults.object(forKey: Defaults.enabled) as? Bool ?? true
        let hour = defaults.object(forKey: Defaults.hour) as? Int ?? 20
        let minute = defaults.object(forKey: Defaults.minute) as? Int ?? 0
        reschedule(enabled: enabled, hour: hour, minute: minute)
    }
}
