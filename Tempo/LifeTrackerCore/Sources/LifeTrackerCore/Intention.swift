import Foundation

/// Whether an intended category was actually acted on for the day.
public struct IntentionOutcome: Identifiable, Sendable, Equatable {
    public let categoryID: UUID
    public let done: Bool
    public var id: UUID { categoryID }

    public init(categoryID: UUID, done: Bool) {
        self.categoryID = categoryID
        self.done = done
    }
}

/// Pure intended-vs-actual math for the morning-intention feature. A category is "done"
/// if any time was logged against it among the given (day's) sessions.
public enum IntentionEvaluator {

    public static func outcomes(
        intendedIDs: [UUID],
        sessions: [Session],
        now: Date = .now
    ) -> [IntentionOutcome] {
        let actedIDs = Set(
            sessions
                .filter { $0.category != nil && $0.elapsed(asOf: now) > 0 }
                .compactMap { $0.category?.id }
        )
        return intendedIDs.map { IntentionOutcome(categoryID: $0, done: actedIDs.contains($0)) }
    }

    /// Count of intended categories that were acted on.
    public static func completedCount(
        intendedIDs: [UUID],
        sessions: [Session],
        now: Date = .now
    ) -> Int {
        outcomes(intendedIDs: intendedIDs, sessions: sessions, now: now).filter(\.done).count
    }
}
