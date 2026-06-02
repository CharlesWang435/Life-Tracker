import Foundation
import SwiftData
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif

private let log = Logger(subsystem: "com.charleswang.lifetracker", category: "SessionActions")

public enum SessionActions {
    public static func fetchActive(in context: ModelContext) -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.endDate == nil }
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            log.error("fetchActive failed: \(error.localizedDescription)")
            return nil
        }
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
        save(context)
        reloadWidgets()
        return session
    }

    @MainActor
    public static func stopActive(in context: ModelContext, at date: Date = .now) {
        guard let active = fetchActive(in: context) else { return }
        active.endDate = date
        save(context)
        reloadWidgets()
    }

    @MainActor
    public static func delete(_ session: Session, in context: ModelContext) {
        context.delete(session)
        save(context)
        reloadWidgets()
    }

    /// Nudge WidgetKit so watch complications / Smart Stack reflect the change at once.
    /// No-op on platforms without WidgetKit.
    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Centralised save so we don't sprinkle `try?` across the codebase.
    /// Logs via OSLog so failures show up in Console.app even in release builds.
    @MainActor
    public static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            log.error("ModelContext.save failed: \(error.localizedDescription)")
        }
    }
}
