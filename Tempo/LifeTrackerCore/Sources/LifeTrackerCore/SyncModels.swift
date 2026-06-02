import Foundation
import SwiftData

/// Codable mirrors of the SwiftData models — the wire format passed between
/// iPhone and Watch over WatchConnectivity. Kept separate from the @Model
/// classes so the transport never touches a live ModelContext off the main actor.

public struct CategoryDTO: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let colorHex: String
    public let sfSymbol: String
    public let sortOrder: Int
    public let createdAt: Date
    public let tapCount: Int

    public init(from c: LogCategory) {
        id = c.id
        name = c.name
        colorHex = c.colorHex
        sfSymbol = c.sfSymbol
        sortOrder = c.sortOrder
        createdAt = c.createdAt
        tapCount = c.tapCount
    }
}

public struct SessionDTO: Codable, Sendable, Equatable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date?
    public let categoryID: UUID?
    public let note: String?

    public init(from s: Session) {
        id = s.id
        startDate = s.startDate
        endDate = s.endDate
        categoryID = s.category?.id
        note = s.note
    }
}

/// A unit of sync: upserts (categories/sessions) plus explicit deletes.
/// Upserts are last-writer-wins by id; deletes are sent separately because a
/// missing record in an upsert set can't be distinguished from "not yet synced".
public struct SyncPayload: Codable, Sendable, Equatable {
    public var categories: [CategoryDTO]
    public var sessions: [SessionDTO]
    public var deletedCategoryIDs: [UUID]
    public var deletedSessionIDs: [UUID]

    public init(
        categories: [CategoryDTO] = [],
        sessions: [SessionDTO] = [],
        deletedCategoryIDs: [UUID] = [],
        deletedSessionIDs: [UUID] = []
    ) {
        self.categories = categories
        self.sessions = sessions
        self.deletedCategoryIDs = deletedCategoryIDs
        self.deletedSessionIDs = deletedSessionIDs
    }

    /// A full snapshot of the store, used as the latest-state application context.
    @MainActor
    public static func fullState(from context: ModelContext) -> SyncPayload {
        let categories = (try? context.fetch(FetchDescriptor<LogCategory>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        return SyncPayload(
            categories: categories.map(CategoryDTO.init(from:)),
            sessions: sessions.map(SessionDTO.init(from:))
        )
    }
}
