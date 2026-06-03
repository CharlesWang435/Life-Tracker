import Foundation

/// Ranks categories for filling a gap by what you usually do during those hours, so the
/// most likely category is offered first. Pure + date-injectable.
public enum GapSuggester {

    /// The hours-of-day a gap spans (e.g. 10:00–12:30 → {10, 11, 12}).
    static func hoursSpanned(_ gap: UntrackedGap, calendar: Calendar) -> Set<Int> {
        let startHour = calendar.component(.hour, from: gap.start)
        // End is exclusive; step back a second so a gap ending exactly on the hour
        // doesn't count the next hour.
        let endHour = calendar.component(.hour, from: gap.end.addingTimeInterval(-1))
        guard endHour >= startHour else { return [startHour] }
        return Set(startHour...endHour)
    }

    /// Categories ordered by historical time logged during the gap's hours (descending),
    /// then by overall frequency (`tapCount`), then manual sort order.
    public static func ranked(
        categories: [LogCategory],
        history: [Session],
        gap: UntrackedGap,
        calendar: Calendar = .current
    ) -> [LogCategory] {
        let gapHours = hoursSpanned(gap, calendar: calendar)
        var score: [UUID: TimeInterval] = [:]
        for session in history {
            guard let id = session.category?.id else { continue }
            let hour = calendar.component(.hour, from: session.startDate)
            if gapHours.contains(hour) {
                score[id, default: 0] += session.elapsed()
            }
        }
        return categories.sorted { lhs, rhs in
            let lScore = score[lhs.id] ?? 0
            let rScore = score[rhs.id] ?? 0
            if lScore != rScore { return lScore > rScore }
            if lhs.tapCount != rhs.tapCount { return lhs.tapCount > rhs.tapCount }
            return lhs.sortOrder < rhs.sortOrder
        }
    }
}
