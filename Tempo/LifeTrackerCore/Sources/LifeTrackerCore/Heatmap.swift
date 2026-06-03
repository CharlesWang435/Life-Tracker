import Foundation

/// One cell in the contribution heatmap.
public struct HeatmapDay: Identifiable, Sendable, Equatable {
    public let date: Date           // start of day
    public let seconds: TimeInterval
    public let isFuture: Bool       // days after today render blank
    public var id: Date { date }

    public init(date: Date, seconds: TimeInterval, isFuture: Bool) {
        self.date = date
        self.seconds = seconds
        self.isFuture = isFuture
    }
}

/// Builds a GitHub-style contribution grid of daily tracked time. Pure + date-injectable.
public enum Heatmap {

    /// Columns of weeks, each a 7-element array (one per weekday, calendar's first weekday
    /// first). The grid is aligned to whole weeks ending in the week that contains `now`.
    public static func grid(
        sessions: [Session],
        weeks: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [[HeatmapDay]] {
        let today = calendar.startOfDay(for: now)
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        guard let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeekStart)
        else { return [] }

        // Per-day totals once, then look up.
        var totals: [Date: TimeInterval] = [:]
        for session in sessions where session.category != nil {
            let day = calendar.startOfDay(for: session.startDate)
            totals[day, default: 0] += session.elapsed(asOf: now)
        }

        var columns: [[HeatmapDay]] = []
        var weekStart = firstWeekStart
        for _ in 0..<weeks {
            var column: [HeatmapDay] = []
            for offset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                column.append(HeatmapDay(
                    date: day,
                    seconds: totals[day] ?? 0,
                    isFuture: day > today
                ))
            }
            columns.append(column)
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        }
        return columns
    }

    /// Largest non-future daily total in the grid — the denominator for intensity shading.
    public static func maxSeconds(_ grid: [[HeatmapDay]]) -> TimeInterval {
        grid.flatMap { $0 }.filter { !$0.isFuture }.map(\.seconds).max() ?? 0
    }
}
