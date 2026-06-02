import Foundation
import EventKit
import Observation
import LifeTrackerCore

/// Bridges EventKit to the pure `TimerSuggester` engine: requests calendar
/// permission and turns today's events into a suggested timer. All reads stay
/// on-device — nothing about your calendar leaves the phone.
@MainActor
@Observable
final class CalendarSuggestionService {
    private let store = EKEventStore()

    /// Current calendar authorization (drives whether we show a prompt or suggestions).
    private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    var isAuthorized: Bool { status == .fullAccess }
    var needsPermissionPrompt: Bool { status == .notDetermined }

    /// Ask iOS for read access. Safe to call repeatedly; updates `status`.
    func requestAccess() async {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            // Outcome is reflected in `status` below regardless of the thrown error.
        }
        status = EKEventStore.authorizationStatus(for: .event)
    }

    /// Today's events → a suggested timer, or `nil` if not authorized / no match.
    func suggestion(categories: [LogCategory], now: Date = .now) -> TimerSuggestion? {
        guard isAuthorized else { return nil }
        let calendar = Calendar.current
        let predicate = store.predicateForEvents(
            withStart: calendar.startOfDay(for: now),
            end: calendar.endOfDay(for: now),
            calendars: nil
        )
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .map { CalendarEvent(title: $0.title ?? "", start: $0.startDate, end: $0.endDate) }
        return TimerSuggester.suggestion(for: events, categories: categories, now: now)
    }
}
