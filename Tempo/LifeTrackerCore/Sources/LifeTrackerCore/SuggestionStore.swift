import Foundation

/// A lightweight, Codable snapshot of the current timer suggestion — small enough
/// to send over WatchConnectivity and to read from a widget without SwiftData.
public struct SuggestionSnapshot: Codable, Sendable, Equatable {
    public let categoryID: UUID
    public let categoryName: String
    public let colorHex: String
    public let sfSymbol: String
    public let reason: String
    /// After this the suggestion is stale and should not be shown.
    public let validUntil: Date

    public init(
        categoryID: UUID,
        categoryName: String,
        colorHex: String,
        sfSymbol: String,
        reason: String,
        validUntil: Date
    ) {
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.colorHex = colorHex
        self.sfSymbol = sfSymbol
        self.reason = reason
        self.validUntil = validUntil
    }
}

/// Optional wrapper so we can encode "no suggestion" (nil) over the wire.
public struct SuggestionEnvelope: Codable, Sendable {
    public let snapshot: SuggestionSnapshot?
    public init(snapshot: SuggestionSnapshot?) { self.snapshot = snapshot }
}

/// Persists the current suggestion in the App Group so widgets (on the same
/// device) can read it. Each device keeps its own copy; the phone pushes its
/// suggestion to the watch over WatchConnectivity, which writes it here too.
public enum SuggestionStore {
    private static let key = "currentSuggestion"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    public static func write(_ snapshot: SuggestionSnapshot?, to defaults: UserDefaults? = nil) {
        guard let store = defaults ?? sharedDefaults else { return }
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
            store.set(data, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    /// Returns the stored suggestion, or nil if absent or expired.
    public static func read(now: Date = .now, from defaults: UserDefaults? = nil) -> SuggestionSnapshot? {
        guard let store = defaults ?? sharedDefaults,
              let data = store.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(SuggestionSnapshot.self, from: data),
              snapshot.validUntil > now else { return nil }
        return snapshot
    }
}

public extension SuggestionSnapshot {
    /// Build a snapshot from a calendar suggestion (validity = the event's end).
    init(from suggestion: TimerSuggestion) {
        self.init(
            categoryID: suggestion.category.id,
            categoryName: suggestion.category.name,
            colorHex: suggestion.category.colorHex,
            sfSymbol: suggestion.category.sfSymbol,
            reason: suggestion.reason,
            validUntil: suggestion.event.end
        )
    }

    /// Build a snapshot from a location suggestion. Location has no natural end,
    /// so the caller supplies how long the suggestion stays fresh.
    init(from suggestion: PlaceSuggestion, validUntil: Date) {
        self.init(
            categoryID: suggestion.category.id,
            categoryName: suggestion.category.name,
            colorHex: suggestion.category.colorHex,
            sfSymbol: suggestion.category.sfSymbol,
            reason: suggestion.reason,
            validUntil: validUntil
        )
    }
}
