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

/// Codable mirror of a `DayEntry` (one reflection/journal per day). Keyed by `date`
/// (start-of-day), which is the entry's logical primary key.
///
/// `photoFilenames` is deliberately omitted: photo files live in each device's own
/// documents directory and are not transferred, so a filename would point at nothing
/// on the peer. `SyncMerger` therefore never touches the local `photoFilenames`,
/// keeping photos a device-local concern.
public struct DayEntryDTO: Codable, Sendable, Equatable {
    public let date: Date
    public let note: String?
    public let noteData: Data?
    public let moodRating: Int?
    public let energyRating: Int?
    public let highlight: String?
    public let intendedCategoryIDs: [UUID]
    public let reflectedAt: Date?

    public init(from e: DayEntry) {
        date = e.date
        note = e.note
        noteData = e.noteData
        moodRating = e.moodRating
        energyRating = e.energyRating
        highlight = e.highlight
        intendedCategoryIDs = e.intendedCategoryIDs
        reflectedAt = e.reflectedAt
    }
}

/// A unit of sync: upserts (categories/sessions/day entries) plus explicit deletes.
/// Upserts are last-writer-wins by id; deletes are sent separately because a
/// missing record in an upsert set can't be distinguished from "not yet synced".
public struct SyncPayload: Codable, Sendable, Equatable {
    public var categories: [CategoryDTO]
    public var sessions: [SessionDTO]
    public var dayEntries: [DayEntryDTO]
    public var deletedCategoryIDs: [UUID]
    public var deletedSessionIDs: [UUID]

    public init(
        categories: [CategoryDTO] = [],
        sessions: [SessionDTO] = [],
        dayEntries: [DayEntryDTO] = [],
        deletedCategoryIDs: [UUID] = [],
        deletedSessionIDs: [UUID] = []
    ) {
        self.categories = categories
        self.sessions = sessions
        self.dayEntries = dayEntries
        self.deletedCategoryIDs = deletedCategoryIDs
        self.deletedSessionIDs = deletedSessionIDs
    }

    /// A full snapshot of the store, used as the latest-state application context.
    @MainActor
    public static func fullState(from context: ModelContext) -> SyncPayload {
        let categories = (try? context.fetch(FetchDescriptor<LogCategory>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let dayEntries = (try? context.fetch(FetchDescriptor<DayEntry>())) ?? []
        return SyncPayload(
            categories: categories.map(CategoryDTO.init(from:)),
            sessions: sessions.map(SessionDTO.init(from:)),
            dayEntries: dayEntries.map(DayEntryDTO.init(from:))
        )
    }
}

/// Backwards-compatible decoding: older peers send payloads without `dayEntries`.
extension SyncPayload {
    private enum CodingKeys: String, CodingKey {
        case categories, sessions, dayEntries, deletedCategoryIDs, deletedSessionIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categories = try c.decodeIfPresent([CategoryDTO].self, forKey: .categories) ?? []
        sessions = try c.decodeIfPresent([SessionDTO].self, forKey: .sessions) ?? []
        dayEntries = try c.decodeIfPresent([DayEntryDTO].self, forKey: .dayEntries) ?? []
        deletedCategoryIDs = try c.decodeIfPresent([UUID].self, forKey: .deletedCategoryIDs) ?? []
        deletedSessionIDs = try c.decodeIfPresent([UUID].self, forKey: .deletedSessionIDs) ?? []
    }
}
