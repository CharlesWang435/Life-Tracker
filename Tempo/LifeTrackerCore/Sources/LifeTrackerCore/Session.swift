import Foundation
import SwiftData

@Model
public final class Session {
    public var id: UUID
    public var startDate: Date
    public var endDate: Date?
    /// Logically always non-nil — the cascade rule on `LogCategory.sessions` deletes
    /// sessions when their category is deleted, so `nil` should never appear at runtime.
    /// SwiftData requires inverse relationships to be optional, hence the `?`.
    /// UI code unwraps defensively and renders a "(deleted category)" fallback row.
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
