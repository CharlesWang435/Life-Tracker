import Foundation

/// An untracked stretch of time between the last logged session and now.
public struct UntrackedGap: Sendable, Equatable, Identifiable {
    public let start: Date
    public let end: Date
    public var duration: TimeInterval { end.timeIntervalSince(start) }
    public var id: TimeInterval { start.timeIntervalSince1970 }

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

/// Pure helpers that flag data-quality issues: untracked gaps and suspiciously long
/// running timers. No SwiftData/UI dependency; date-injectable for tests.
public enum CaptureQuality {

    public static let defaultGapMinimum: TimeInterval = 30 * 60      // 30 minutes
    public static let defaultLongRunning: TimeInterval = 4 * 3600    // 4 hours

    /// The current untracked gap: from the most recent completed session's end to `now`,
    /// when nothing is running and the gap is at least `minimum`. Considers today only, so
    /// a fresh morning before any logging doesn't read as a giant gap.
    public static func currentGap(
        sessions: [Session],
        now: Date = .now,
        minimum: TimeInterval = defaultGapMinimum,
        calendar: Calendar = .current
    ) -> UntrackedGap? {
        if sessions.contains(where: { $0.isActive }) { return nil }   // something running → no gap
        let today = calendar.startOfDay(for: now)
        let endsToday = sessions
            .filter { $0.startDate >= today }
            .compactMap { $0.endDate }
        guard let lastEnd = endsToday.max(), lastEnd < now else { return nil }
        guard now.timeIntervalSince(lastEnd) >= minimum else { return nil }
        return UntrackedGap(start: lastEnd, end: now)
    }

    /// Every untracked hole in today's timeline: the gaps between tracked sessions and the
    /// trailing gap up to `now`. The window starts at the day's first tracked session (so
    /// untracked pre-dawn time isn't nagged about) and ends at `now`. Active sessions count
    /// as occupied through `now`, so nothing is flagged while a timer runs.
    public static func allGaps(
        sessions: [Session],
        now: Date = .now,
        minimum: TimeInterval = defaultGapMinimum,
        calendar: Calendar = .current
    ) -> [UntrackedGap] {
        let today = calendar.startOfDay(for: now)
        let todays = sessions.filter { ($0.endDate ?? now) > today && $0.startDate < now }
        guard let earliest = todays.map(\.startDate).min() else { return [] }

        let windowStart = max(today, earliest)
        let intervals = todays
            .map { (max(windowStart, $0.startDate), min(now, $0.endDate ?? now)) }
            .filter { $0.0 < $0.1 }
            .sorted { $0.0 < $1.0 }

        // Merge overlapping/touching occupied intervals.
        var merged: [(start: Date, end: Date)] = []
        for interval in intervals {
            if let last = merged.last, interval.0 <= last.end {
                merged[merged.count - 1].end = max(last.end, interval.1)
            } else {
                merged.append((interval.0, interval.1))
            }
        }

        // Complement = the gaps between occupied intervals, plus the trailing gap to now.
        var gaps: [UntrackedGap] = []
        var cursor = windowStart
        for interval in merged {
            if interval.start > cursor, interval.start.timeIntervalSince(cursor) >= minimum {
                gaps.append(UntrackedGap(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        if now > cursor, now.timeIntervalSince(cursor) >= minimum {
            gaps.append(UntrackedGap(start: cursor, end: now))
        }
        return gaps
    }

    /// Split a gap into consecutive sub-intervals for the given ordered `durations`
    /// (seconds), back-to-back from `gap.start`. Zero/negative durations are skipped, and
    /// intervals are clamped so they never run past `gap.end`. Used to backfill a gap with
    /// several categories at once.
    public static func segments(
        in gap: UntrackedGap,
        durations: [TimeInterval]
    ) -> [(start: Date, end: Date)] {
        var result: [(start: Date, end: Date)] = []
        var cursor = gap.start
        for duration in durations where duration > 0 {
            guard cursor < gap.end else { break }
            let end = min(gap.end, cursor.addingTimeInterval(duration))
            result.append((cursor, end))
            cursor = end
        }
        return result
    }

    /// Elapsed time of the active session if it exceeds `threshold`, else nil — the signal
    /// for a gentle "still running?" nudge.
    public static func longRunning(
        activeSession: Session?,
        now: Date = .now,
        threshold: TimeInterval = defaultLongRunning
    ) -> TimeInterval? {
        guard let session = activeSession, session.isActive else { return nil }
        let elapsed = session.elapsed(asOf: now)
        return elapsed >= threshold ? elapsed : nil
    }
}
