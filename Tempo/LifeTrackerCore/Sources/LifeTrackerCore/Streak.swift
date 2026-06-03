import Foundation

/// Generic consecutive-day streak math, shared by every kind of streak (days logged,
/// days reflected, …). Pure and date-injectable for testing.
public enum Streak {

    /// Current run of consecutive days ending today. Today counts as "in progress": if
    /// today isn't in `days` we anchor on yesterday, so an as-yet-incomplete today doesn't
    /// reset a real streak. Returns 0 only when neither today nor yesterday qualifies.
    public static func current(
        days: [Date],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let set = Set(days.map { calendar.startOfDay(for: $0) })
        guard !set.isEmpty else { return 0 }

        let startOfToday = calendar.startOfDay(for: today)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return 0
        }

        var cursor: Date
        if set.contains(startOfToday) {
            cursor = startOfToday
        } else if set.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var count = 0
        while set.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// Distinct days (start-of-day) on which at least one session was logged.
    public static func loggedDays(from sessions: [Session], calendar: Calendar = .current) -> [Date] {
        Set(sessions.map { calendar.startOfDay(for: $0.startDate) }).sorted()
    }
}
