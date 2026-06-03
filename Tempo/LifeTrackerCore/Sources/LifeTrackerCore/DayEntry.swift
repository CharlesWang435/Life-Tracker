import Foundation
import SwiftData

/// One reflection/journal entry per calendar day. `date` is the start-of-day key;
/// uniqueness (one entry per day) is enforced in code via `DayEntryActions.entry(for:in:)`,
/// since SwiftData has no portable unique-constraint story across the targets yet.
@Model
public final class DayEntry {
    /// Start-of-day for the day this entry describes. The logical primary key.
    public var date: Date
    /// Plain-text mirror of the note (used for previews/search). The rich version lives in
    /// `noteData`; `note` is kept in sync as the stripped string.
    public var note: String?
    /// The journal note as an encoded `AttributedString` (bold/italic/lists). Optional so
    /// existing entries migrate cleanly; falls back to `note` when absent.
    public var noteData: Data?
    public var moodRating: Int?       // 1–5
    public var energyRating: Int?     // 1–5
    /// One-line "highlight of the day".
    public var highlight: String?
    /// Filenames of photos stored in the app's documents directory (Phase 3 mechanism).
    public var photoFilenames: [String] = []
    /// Categories the user planned to spend time on today (Phase 4D). Harmless to carry now.
    public var intendedCategoryIDs: [UUID] = []
    /// Set when the evening check-in is completed. Drives the reflection streak;
    /// distinct from any individual field so "reflected with just a note" still counts.
    public var reflectedAt: Date?

    public init(
        date: Date,
        note: String? = nil,
        moodRating: Int? = nil,
        energyRating: Int? = nil,
        highlight: String? = nil,
        photoFilenames: [String] = [],
        intendedCategoryIDs: [UUID] = [],
        reflectedAt: Date? = nil
    ) {
        self.date = date
        self.note = note
        self.moodRating = moodRating
        self.energyRating = energyRating
        self.highlight = highlight
        self.photoFilenames = photoFilenames
        self.intendedCategoryIDs = intendedCategoryIDs
        self.reflectedAt = reflectedAt
    }

    /// True once the user has completed a reflection for this day.
    public var isReflected: Bool { reflectedAt != nil }

    /// The rich journal note. Reads `noteData` (decoding the `AttributedString`), falling
    /// back to the plain `note`. Writing updates both `noteData` and the plain `note` mirror.
    public var attributedNote: AttributedString {
        get {
            if let data = noteData,
               let decoded = try? JSONDecoder().decode(AttributedString.self, from: data) {
                return decoded
            }
            return AttributedString(note ?? "")
        }
        set {
            let plain = String(newValue.characters)
            note = plain.isEmpty ? nil : plain
            noteData = plain.isEmpty ? nil : (try? JSONEncoder().encode(newValue))
        }
    }
}
