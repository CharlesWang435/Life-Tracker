import Foundation
import SwiftData

@Model
public final class LogCategory {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var sfSymbol: String
    public var sortOrder: Int
    public var createdAt: Date
    public var tapCount: Int = 0

    // MARK: Goal / budget (Phase 4B). `goalMinutes == nil` means no goal set.
    public var goalMinutes: Int? = nil
    public var goalPeriodRaw: String = GoalPeriod.daily.rawValue
    public var goalDirectionRaw: String = GoalDirection.atLeast.rawValue

    /// Typed accessors over the persisted raw strings (kept raw for SwiftData stability).
    public var goalPeriod: GoalPeriod {
        get { GoalPeriod(rawValue: goalPeriodRaw) ?? .daily }
        set { goalPeriodRaw = newValue.rawValue }
    }
    public var goalDirection: GoalDirection {
        get { GoalDirection(rawValue: goalDirectionRaw) ?? .atLeast }
        set { goalDirectionRaw = newValue.rawValue }
    }
    public var hasGoal: Bool { (goalMinutes ?? 0) > 0 }

    @Relationship(deleteRule: .cascade, inverse: \Session.category)
    public var sessions: [Session] = []

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        sfSymbol: String,
        sortOrder: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sfSymbol = sfSymbol
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
