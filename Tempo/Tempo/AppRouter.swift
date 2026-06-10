import SwiftUI
import SwiftData
import UserNotifications
import LifeTrackerCore

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
    /// Used to start a timer directly from a place-arrival notification's action.
    nonisolated(unsafe) let container: ModelContainer

    init(router: AppRouter, container: ModelContainer) {
        self.router = router
        self.container = container
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        // Place-arrival: the "Start" action launches the suggested timer; tapping the
        // body just opens the app to Today.
        if userInfo["placeArrival"] as? Bool == true {
            await handlePlaceArrival(response: response, userInfo: userInfo)
            return
        }

        let id = userInfo["deepLink"] as? String
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

    @MainActor
    private func handlePlaceArrival(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        router.selectedTab = .today
        guard response.actionIdentifier == PlaceArrivalNotifications.startActionID,
              let idString = userInfo["categoryID"] as? String,
              let categoryID = UUID(uuidString: idString) else { return }
        let context = container.mainContext
        let categories = (try? context.fetch(FetchDescriptor<LogCategory>())) ?? []
        guard let category = categories.first(where: { $0.id == categoryID }) else { return }
        SessionActions.start(category: category, in: context)
    }

    /// Show the banner even while Tempo is foregrounded, so the reminder isn't silently dropped.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
