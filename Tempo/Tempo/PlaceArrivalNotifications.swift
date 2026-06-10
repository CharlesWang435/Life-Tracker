import Foundation
import UserNotifications

/// Local notifications fired when you arrive at a tagged place ("You're at the Gym —
/// start Exercise?"). Local-only, so no special entitlement and works on a free Apple
/// ID. The notification carries a "Start" action that launches the timer directly.
enum PlaceArrivalNotifications {
    static let categoryID = "tempo.place.arrival"
    static let startActionID = "tempo.place.start"

    /// Register the notification category and its "Start" action. Call once at launch.
    /// Note: this replaces the app's notification categories — Tempo has only this one.
    static func registerCategory() {
        let start = UNNotificationAction(
            identifier: startActionID,
            title: "Start Timer",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [start],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Post an arrival suggestion immediately. One pending notification per category
    /// (the id is category-keyed) so repeated arrivals don't stack up.
    static func notifyArrival(placeName: String, categoryID categoryUUID: UUID, categoryName: String) {
        let content = UNMutableNotificationContent()
        content.title = "You're at \(placeName)"
        content.body = "Start your \(categoryName) timer?"
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            "placeArrival": true,
            "categoryID": categoryUUID.uuidString
        ]
        let request = UNNotificationRequest(
            identifier: "tempo.place.arrival.\(categoryUUID.uuidString)",
            content: content,
            trigger: nil   // deliver now
        )
        UNUserNotificationCenter.current().add(request)
    }
}
