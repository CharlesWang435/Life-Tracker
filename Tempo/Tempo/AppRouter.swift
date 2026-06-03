import SwiftUI
import UserNotifications

/// The app's top-level tabs. Used as the `TabView` selection so the Home dashboard
/// can deep-link into any feature tab.
enum AppTab: Hashable {
    case home, today, reflect, history
}

/// A screen a notification tap can route to. Modeled as one optional value (not separate
/// booleans) so two reminders firing together can't leave a stuck flag that suppresses a
/// later sheet.
enum DeepLink: String, Identifiable {
    case reflection, dayReview, weeklyReview
    var id: String { rawValue }
}

/// App-wide navigation signals that originate outside the view tree (e.g. a tapped
/// notification) or from the Home dashboard. Injected into the environment.
@Observable
final class AppRouter {
    /// Currently selected tab. Home cards write to this to switch tabs.
    var selectedTab: AppTab = .home
    /// The screen to present from a notification tap (nil = none). One value, so links
    /// can't collide.
    var deepLink: DeepLink?
}

/// Routes notification taps into the app. Retained by `TempoApp` and set as the
/// `UNUserNotificationCenter` delegate so taps flip the shared `AppRouter`.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.content.userInfo["deepLink"] as? String
        let link: DeepLink?
        switch id {
        case ReflectionNotifications.deepLinkID: link = .reflection
        case UntrackedNotifications.deepLinkID: link = .dayReview
        case WeeklyReviewNotifications.deepLinkID: link = .weeklyReview
        default: link = nil
        }
        if let link {
            await MainActor.run { router.deepLink = link }
        }
    }

    /// Show the banner even while Tempo is foregrounded, so the reminder isn't silently dropped.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
