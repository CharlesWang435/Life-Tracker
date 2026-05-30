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
