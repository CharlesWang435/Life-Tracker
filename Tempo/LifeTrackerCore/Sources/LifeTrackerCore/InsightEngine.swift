import Foundation

/// One auto-generated insight card.
public struct Insight: Identifiable, Sendable, Equatable {
    public let id: String          // stable per kind, so the UI can animate updates
    public let title: String       // short headline
    public let detail: String      // supporting line
    public let systemImage: String
    public let colorHex: String?   // tint for category-based insights

    public init(id: String, title: String, detail: String, systemImage: String, colorHex: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.colorHex = colorHex
    }
}

/// Derives a ranked list of insights from sessions + reflections. Pure and
/// date-injectable; the UI just renders the top N.
public enum InsightEngine {

    public static func insights(
        sessions: [Session],
        dayEntries: [DayEntry] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Insight] {
        var result: [Insight] = []
        if let i = weekOverWeek(sessions, now: now, calendar: calendar) { result.append(i) }
        if let i = topCategoryThisWeek(sessions, now: now, calendar: calendar) { result.append(i) }
        if let i = mostActiveHour(sessions, now: now, calendar: calendar) { result.append(i) }
        if let i = longestSession(sessions, calendar: calendar) { result.append(i) }
        if let i = averageMood(dayEntries, now: now, calendar: calendar) { result.append(i) }
        return result
    }

    // MARK: Individual insights

    /// This week's total tracked time vs last week's.
    static func weekOverWeek(_ sessions: [Session], now: Date, calendar: Calendar) -> Insight? {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start)!

        let thisTotal = total(sessions, from: thisWeek.start, to: now, asOf: now)
        let lastTotal = total(sessions, from: lastWeekStart, to: thisWeek.start, asOf: now)
        guard thisTotal > 0 || lastTotal > 0 else { return nil }

        let delta = thisTotal - lastTotal
        let detail: String
        if lastTotal == 0 {
            detail = "Your first tracked week — keep going!"
        } else if abs(delta) < 60 {
            detail = "About the same as last week"
        } else {
            detail = "\(delta > 0 ? "Up" : "Down") \(abs(delta).formattedShort) from last week"
        }
        return Insight(
            id: "weekOverWeek",
            title: "\(thisTotal.formattedShort) tracked this week",
            detail: detail,
            systemImage: delta >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis"
        )
    }

    /// The category you've spent the most time on this week.
    static func topCategoryThisWeek(_ sessions: [Session], now: Date, calendar: Calendar) -> Insight? {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let weekSessions = sessions.filter { $0.startDate >= week.start && $0.startDate < now }
        guard let top = SessionAggregates.categoryTotals(weekSessions, asOf: now).first else { return nil }
        return Insight(
            id: "topCategory",
            title: "Most time on \(top.category.name)",
            detail: "\(top.duration.formattedShort) this week",
            systemImage: top.category.sfSymbol,
            colorHex: top.category.colorHex
        )
    }

    /// The hour of day you most often start an activity.
    static func mostActiveHour(_ sessions: [Session], now: Date, calendar: Calendar) -> Insight? {
        let real = sessions.filter { $0.elapsed(asOf: now) >= 60 }   // ignore accidental taps
        guard real.count >= 3 else { return nil }
        let byHour = Dictionary(grouping: real) { calendar.component(.hour, from: $0.startDate) }
        // Tie-break on the earlier hour so the result is stable across refreshes.
        guard let (hour, items) = byHour.max(by: {
            $0.value.count != $1.value.count ? $0.value.count < $1.value.count : $0.key > $1.key
        }) else { return nil }
        return Insight(
            id: "activeHour",
            title: "You usually start around \(hourLabel(hour))",
            detail: "\(items.count) sessions began then",
            systemImage: "clock"
        )
    }

    /// The single longest completed session.
    static func longestSession(_ sessions: [Session], calendar: Calendar) -> Insight? {
        let completed = sessions.filter { $0.endDate != nil && $0.category != nil }
        guard let longest = completed.max(by: { $0.elapsed() < $1.elapsed() }),
              let category = longest.category, longest.elapsed() >= 60 else { return nil }
        let weekday = longest.startDate.formatted(.dateTime.weekday(.wide))
        return Insight(
            id: "longestSession",
            title: "Longest session: \(longest.elapsed().formattedShort)",
            detail: "\(category.name) on \(weekday)",
            systemImage: "timer",
            colorHex: category.colorHex
        )
    }

    /// Average mood over the last 7 days of reflections.
    static func averageMood(_ dayEntries: [DayEntry], now: Date, calendar: Calendar) -> Insight? {
        let weekStart = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))!
        let moods = dayEntries
            .filter { $0.date >= weekStart }
            .compactMap(\.moodRating)
        guard moods.count >= 2 else { return nil }
        let avg = Double(moods.reduce(0, +)) / Double(moods.count)
        return Insight(
            id: "avgMood",
            title: String(format: "Average mood %.1f / 5", avg),
            detail: "Across \(moods.count) reflections this week",
            systemImage: "face.smiling"
        )
    }

    // MARK: Helpers

    private static func total(_ sessions: [Session], from: Date, to: Date, asOf: Date) -> TimeInterval {
        sessions
            .filter { $0.startDate >= from && $0.startDate < to && $0.category != nil }
            .reduce(0.0) { $0 + $1.elapsed(asOf: asOf) }
    }

    static func hourLabel(_ hour: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve) \(period)"
    }
}
