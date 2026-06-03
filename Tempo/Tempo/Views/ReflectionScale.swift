import Foundation

/// The two 1–5 axes captured during reflection, and their emoji scales. Shared by the
/// check-in selector (`RatingRow`), the trend chart, and the history rows so the emoji
/// for a given rating is defined in exactly one place.
enum ReflectionAxis: String, CaseIterable, Identifiable {
    case mood, energy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mood: return "Mood"
        case .energy: return "Energy"
        }
    }

    /// Index 0 = rating 1 … index 4 = rating 5.
    var emojis: [String] {
        switch self {
        case .mood: return ["😞", "😕", "😐", "🙂", "😄"]
        case .energy: return ["😴", "🥱", "😌", "💪", "⚡️"]
        }
    }

    /// Emoji for a 1-based rating, or nil if out of range.
    func emoji(for rating: Int) -> String? {
        guard (1...emojis.count).contains(rating) else { return nil }
        return emojis[rating - 1]
    }
}
