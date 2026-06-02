import Foundation
import SwiftData
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif

private let log = Logger(subsystem: "com.charleswang.lifetracker", category: "SyncMerger")

/// Applies a received `SyncPayload` to the local store: upsert-by-id for
/// categories/sessions, then explicit deletes. Saves with a plain
/// `context.save()` (NOT `SessionActions.save`) so applying a remote change
/// never triggers another outgoing broadcast — that would loop forever.
public enum SyncMerger {

    @MainActor
    public static func apply(_ payload: SyncPayload, to context: ModelContext) {
        for dto in payload.categories { upsert(dto, in: context) }
        for dto in payload.sessions { upsert(dto, in: context) }
        for id in payload.deletedCategoryIDs { deleteCategory(id, in: context) }
        for id in payload.deletedSessionIDs { deleteSession(id, in: context) }

        do {
            try context.save()
        } catch {
            log.error("sync save failed: \(error.localizedDescription)")
        }

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: Upserts

    @MainActor
    private static func upsert(_ dto: CategoryDTO, in context: ModelContext) {
        if let existing = category(dto.id, in: context) {
            existing.name = dto.name
            existing.colorHex = dto.colorHex
            existing.sfSymbol = dto.sfSymbol
            existing.sortOrder = dto.sortOrder
            existing.createdAt = dto.createdAt
            // Tap counts can be incremented on either device — keep the larger.
            existing.tapCount = max(existing.tapCount, dto.tapCount)
        } else {
            let created = LogCategory(
                id: dto.id,
                name: dto.name,
                colorHex: dto.colorHex,
                sfSymbol: dto.sfSymbol,
                sortOrder: dto.sortOrder,
                createdAt: dto.createdAt
            )
            created.tapCount = dto.tapCount
            context.insert(created)
        }
    }

    @MainActor
    private static func upsert(_ dto: SessionDTO, in context: ModelContext) {
        let linkedCategory = dto.categoryID.flatMap { category($0, in: context) }
        if let existing = session(dto.id, in: context) {
            existing.startDate = dto.startDate
            existing.endDate = dto.endDate
            existing.note = dto.note
            existing.category = linkedCategory
        } else {
            let created = Session(
                id: dto.id,
                startDate: dto.startDate,
                endDate: dto.endDate,
                category: linkedCategory,
                note: dto.note
            )
            context.insert(created)
        }
    }

    // MARK: Deletes

    @MainActor
    private static func deleteCategory(_ id: UUID, in context: ModelContext) {
        // Deleting a category cascades to its sessions, matching the local @Relationship rule.
        if let existing = category(id, in: context) {
            context.delete(existing)
        }
    }

    @MainActor
    private static func deleteSession(_ id: UUID, in context: ModelContext) {
        if let existing = session(id, in: context) {
            context.delete(existing)
        }
    }

    // MARK: Lookups

    @MainActor
    private static func category(_ id: UUID, in context: ModelContext) -> LogCategory? {
        var descriptor = FetchDescriptor<LogCategory>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func session(_ id: UUID, in context: ModelContext) -> Session? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
