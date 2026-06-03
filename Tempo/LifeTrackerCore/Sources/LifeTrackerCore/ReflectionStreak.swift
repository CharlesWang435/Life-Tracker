import Foundation

/// Pure streak math over the set of reflected days. No SwiftData dependency, so it's
/// trivially unit-testable by injecting `today` and a fixed `calendar`.
public enum ReflectionStreak {

    /// Current run of consecutive reflected days ending today.
    ///
    /// Today counts as "in progress": if today hasn't been reflected yet we anchor on
    /// yesterday, so an as-yet-unreflected today doesn't reset a real streak to 0.
    /// Returns 0 only when neither today nor yesterday is reflected.
    public static func current(
        reflectedDays: [Date],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        Streak.current(days: reflectedDays, today: today, calendar: calendar)
    }
}
