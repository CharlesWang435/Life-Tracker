import Foundation

/// One category's summed time over some set of sessions.
public struct CategoryTotal: Identifiable, Sendable {
    public let category: LogCategory
    public let duration: TimeInterval
    public var id: UUID { category.id }

    public init(category: LogCategory, duration: TimeInterval) {
        self.category = category
        self.duration = duration
    }
}

/// One category's time within a single day — the unit for stacked weekly bars.
public struct DailyCategoryTotal: Identifiable, Sendable {
    public let day: Date
    public let category: LogCategory
    public let duration: TimeInterval
    public var id: String { "\(day.timeIntervalSince1970)-\(category.id)" }

    public init(day: Date, category: LogCategory, duration: TimeInterval) {
        self.day = day
        self.category = category
        self.duration = duration
    }
}

/// Shared session-rollup math used by both the iPhone charts and the Watch charts.
/// Centralised here so the grouping/summing logic lives in one tested place.
public enum SessionAggregates {

    /// Total elapsed time per category, descending, dropping categories with no time.
    /// Sessions whose category was deleted (`category == nil`) are ignored.
    public static func categoryTotals(
        _ sessions: [Session],
        asOf reference: Date = .now
    ) -> [CategoryTotal] {
        let groups = Dictionary(grouping: sessions, by: { $0.category?.id })
        return groups.compactMap { _, items -> CategoryTotal? in
            guard let category = items.first?.category else { return nil }
            let total = items.reduce(0.0) { $0 + $1.elapsed(asOf: reference) }
            guard total > 0 else { return nil }
            return CategoryTotal(category: category, duration: total)
        }
        .sorted { $0.duration > $1.duration }
    }

    /// Sum of all category time across the given sessions.
    public static func grandTotal(
        _ sessions: [Session],
        asOf reference: Date = .now
    ) -> TimeInterval {
        sessions.reduce(0.0) { $0 + ($1.category == nil ? 0 : $1.elapsed(asOf: reference)) }
    }

    /// Per-day, per-category totals for the last `days` calendar days (oldest first),
    /// suitable for a stacked bar chart. A session is attributed to the day it started.
    public static func dailyCategoryTotals(
        _ sessions: [Session],
        days dayCount: Int,
        calendar: Calendar = .current,
        asOf reference: Date = .now
    ) -> [DailyCategoryTotal] {
        let today = calendar.startOfDay(for: reference)
        let days = (0..<dayCount)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .reversed()

        return days.flatMap { day -> [DailyCategoryTotal] in
            let dayEnd = calendar.endOfDay(for: day)
            let daySessions = sessions.filter { $0.startDate >= day && $0.startDate < dayEnd }
            let byCategory = Dictionary(grouping: daySessions, by: { $0.category?.id })
            return byCategory.compactMap { _, items -> DailyCategoryTotal? in
                guard let category = items.first?.category else { return nil }
                let total = items.reduce(0.0) { $0 + $1.elapsed(asOf: reference) }
                guard total > 0 else { return nil }
                return DailyCategoryTotal(day: day, category: category, duration: total)
            }
        }
    }
}
