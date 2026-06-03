import SwiftUI
import LifeTrackerCore

/// Renders the day's intended categories as chips with a done/pending state. Shared by the
/// Today plan section, the Home intentions module, and the reflection comparison.
struct IntentionChips: View {
    let categories: [LogCategory]
    let intendedIDs: [UUID]
    let sessions: [Session]
    var compact: Bool = false

    private var items: [(category: LogCategory, done: Bool)] {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        return IntentionEvaluator.outcomes(intendedIDs: intendedIDs, sessions: sessions)
            .compactMap { outcome in
                byID[outcome.categoryID].map { ($0, outcome.done) }
            }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.category.id) { item in
                    let color = Color(hex: item.category.colorHex)
                    HStack(spacing: 5) {
                        Image(systemName: item.done ? "checkmark.circle.fill" : item.category.sfSymbol)
                            .foregroundStyle(item.done ? .green : color)
                        if !compact {
                            Text(item.category.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
