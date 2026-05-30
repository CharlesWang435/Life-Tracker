import Foundation
import SwiftData

public enum SessionActions {
    public static func fetchActive(in context: ModelContext) -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.endDate == nil }
        )
        return try? context.fetch(descriptor).first
    }

    @MainActor
    @discardableResult
    public static func start(
        category: LogCategory,
        in context: ModelContext,
        at date: Date = .now
    ) -> Session {
        stopActive(in: context, at: date)
        category.tapCount += 1
        let session = Session(startDate: date, category: category)
        context.insert(session)
        try? context.save()
        return session
    }

    @MainActor
    public static func stopActive(in context: ModelContext, at date: Date = .now) {
        guard let active = fetchActive(in: context) else { return }
        active.endDate = date
        try? context.save()
    }

    @MainActor
    public static func delete(_ session: Session, in context: ModelContext) {
        context.delete(session)
        try? context.save()
    }
}
