import Foundation

/// Selectable window for the reflection trend chart + history list.
/// Rolling windows anchored on "now" (e.g. `.week` = the last 7 days including today).
public enum ReflectionTimeRange: String, CaseIterable, Identifiable, Sendable {
    case week, month, year, all

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .all: return "All"
        }
    }

    /// Inclusive lower bound for the window, or `nil` for `.all` (no lower bound).
    /// Returned as a start-of-day so it lines up with `DayEntry.date` keys.
    public func startDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -6, to: today)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: today)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: today)
        case .all:
            return nil
        }
    }

    /// Whether `date` falls within this window relative to `now`.
    public func contains(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let start = startDate(now: now, calendar: calendar) else { return true }
        return date >= start
    }
}
