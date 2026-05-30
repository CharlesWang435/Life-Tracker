import Foundation
import SwiftData

@Model
public final class Session {
    public var id: UUID
    public var startDate: Date
    public var endDate: Date?
    public var category: LogCategory?
    public var note: String?

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        category: LogCategory? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.note = note
    }

    public var isActive: Bool { endDate == nil }

    public func elapsed(asOf reference: Date = .now) -> TimeInterval {
        (endDate ?? reference).timeIntervalSince(startDate)
    }
}
