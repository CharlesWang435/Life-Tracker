import Foundation

/// A calendar event reduced to just what the suggester needs — keeps the
/// engine free of EventKit so it stays pure and unit-testable.
public struct CalendarEvent: Sendable, Equatable {
    public let title: String
    public let start: Date
    public let end: Date

    public init(title: String, start: Date, end: Date) {
        self.title = title
        self.start = start
        self.end = end
    }
}

/// A proposed timer to start, derived from a calendar event.
public struct TimerSuggestion {
    public let category: LogCategory
    public let event: CalendarEvent
    /// True when the event is happening right now (vs. starting soon).
    public let isHappeningNow: Bool

    public var reason: String {
        isHappeningNow
            ? "On now: \(event.title)"
            : "Up next: \(event.title)"
    }
}

/// Maps calendar events to a category to suggest starting.
///
/// Matching is intentionally simple for v1:
/// 1. **Direct** — the event title contains a category's name ("Deep Work" -> Work).
/// 2. **Keyword** — the title contains a known keyword mapped to a default
///    category name ("Gym" -> Exercise). Keywords only help the *default*
///    categories; renamed/custom categories still match by their own name.
public enum TimerSuggester {

    /// Keyword hints keyed by the default category names from `DefaultCategories`.
    static let keywords: [String: [String]] = [
        "Sleep":    ["sleep", "nap", "bedtime"],
        "Work":     ["meeting", "standup", "stand-up", "sync", "1:1", "call", "review", "interview", "work", "deadline"],
        "Study":    ["class", "lecture", "study", "homework", "reading", "exam", "seminar", "course"],
        "Exercise": ["gym", "workout", "run", "yoga", "lift", "training", "ride", "swim", "pilates", "spin"],
        "Cook":     ["cook", "baking", "meal prep", "meal-prep"],
        "Social":   ["party", "drinks", "hangout", "coffee", "brunch", "dinner with", "lunch with", "date"],
        "Commute":  ["commute", "flight", "drive", "travel", "train", "airport"],
        "Chill":    ["chill", "relax", "movie", "tv", "break", "rest"]
    ]

    /// Picks a suggestion from the given events: an event happening now wins,
    /// otherwise the soonest event starting within `lookahead`.
    /// Returns `nil` if nothing relevant matches a category.
    public static func suggestion(
        for events: [CalendarEvent],
        categories: [LogCategory],
        now: Date = .now,
        lookahead: TimeInterval = 15 * 60
    ) -> TimerSuggestion? {
        let upperBound = now.addingTimeInterval(lookahead)
        let relevant = events
            .filter { $0.end > now && $0.start <= upperBound }
            .sorted { $0.start < $1.start }

        for event in relevant {
            if let category = match(title: event.title, categories: categories) {
                let happeningNow = event.start <= now && now < event.end
                return TimerSuggestion(category: category, event: event, isHappeningNow: happeningNow)
            }
        }
        return nil
    }

    /// Resolves a single event title to a category, or `nil`.
    static func match(title: String, categories: [LogCategory]) -> LogCategory? {
        let lower = title.lowercased()

        // 1) Direct: the title mentions a category by name.
        if let direct = categories.first(where: { !$0.name.isEmpty && lower.contains($0.name.lowercased()) }) {
            return direct
        }

        // 2) Keyword: the title contains a known keyword for a default category.
        for category in categories {
            let hints = keywords[category.name] ?? []
            if hints.contains(where: { lower.contains($0) }) {
                return category
            }
        }
        return nil
    }
}
