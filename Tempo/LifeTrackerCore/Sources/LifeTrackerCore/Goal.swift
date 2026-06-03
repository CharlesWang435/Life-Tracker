import Foundation

/// The window a goal is measured over.
public enum GoalPeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily, weekly
    public var id: String { rawValue }
    public var label: String { self == .daily ? "Daily" : "Weekly" }
}

/// Whether a goal is a target to reach or a cap not to exceed.
public enum GoalDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case atLeast   // a target: "at least 45m exercise"
    case atMost    // a cap:    "at most 8h work"
    public var id: String { rawValue }
    public var label: String { self == .atLeast ? "Target" : "Limit" }
}

/// The evaluated state of one category's goal for the current period.
public struct GoalStatus: Sendable, Equatable {
    public let target: TimeInterval     // seconds
    public let spent: TimeInterval      // seconds in the current period
    public let direction: GoalDirection
    public let period: GoalPeriod

    public init(target: TimeInterval, spent: TimeInterval, direction: GoalDirection, period: GoalPeriod) {
        self.target = target
        self.spent = spent
        self.direction = direction
        self.period = period
    }

    /// Progress toward the target; can exceed 1 (e.g. a cap that's been blown).
    public var fraction: Double { target > 0 ? spent / target : 0 }
    /// Ring fill, clamped to 0...1.
    public var clampedFraction: Double { min(max(fraction, 0), 1) }

    /// Whether the goal is currently satisfied.
    public var isMet: Bool {
        switch direction {
        case .atLeast: return spent >= target
        case .atMost:  return spent <= target
        }
    }

    /// Over the target — the meaningful "warning" state for a cap.
    public var isOver: Bool { spent > target }

    /// Time still allowed (cap) or still needed (target).
    public var remaining: TimeInterval { max(0, target - spent) }
    /// Time spent beyond the target.
    public var overage: TimeInterval { max(0, spent - target) }
}

/// Pure goal math: how much has been spent on a category this period, and the resulting
/// status. No SwiftData/UI dependency, so it's unit-testable with injected `now`.
public enum GoalEvaluator {

    /// Start of the current period relative to `now`.
    public static func periodStart(_ period: GoalPeriod, now: Date, calendar: Calendar) -> Date {
        switch period {
        case .daily:
            return calendar.startOfDay(for: now)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start
                ?? calendar.startOfDay(for: now)
        }
    }

    /// Seconds spent on `categoryID` within the current `period`. Each session contributes
    /// only the portion that *overlaps* the window, so a session that started before the
    /// period (e.g. a timer running since before midnight, or across the week boundary)
    /// still counts its in-period time. Active sessions are measured against `now`.
    public static func spent(
        categoryID: UUID,
        period: GoalPeriod,
        sessions: [Session],
        now: Date,
        calendar: Calendar
    ) -> TimeInterval {
        let start = periodStart(period, now: now, calendar: calendar)
        return sessions.reduce(0.0) { total, session in
            guard session.category?.id == categoryID else { return total }
            let from = max(start, session.startDate)
            let to = min(now, session.endDate ?? now)
            return to > from ? total + to.timeIntervalSince(from) : total
        }
    }

    /// Status for a category's goal, or nil if it has none.
    public static func status(
        for category: LogCategory,
        sessions: [Session],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> GoalStatus? {
        guard let minutes = category.goalMinutes, minutes > 0 else { return nil }
        let spentSeconds = spent(
            categoryID: category.id,
            period: category.goalPeriod,
            sessions: sessions,
            now: now,
            calendar: calendar
        )
        return GoalStatus(
            target: TimeInterval(minutes * 60),
            spent: spentSeconds,
            direction: category.goalDirection,
            period: category.goalPeriod
        )
    }
}
