import Foundation
import SwiftData

public enum DefaultCategories {
    public struct Seed {
        public let name: String
        public let colorHex: String
        public let sfSymbol: String
    }

    public static let seeds: [Seed] = [
        Seed(name: "Sleep",    colorHex: "#5B6CFF", sfSymbol: "moon.zzz.fill"),
        Seed(name: "Work",     colorHex: "#FF6B6B", sfSymbol: "laptopcomputer"),
        Seed(name: "Study",    colorHex: "#FFB84D", sfSymbol: "book.fill"),
        Seed(name: "Exercise", colorHex: "#4ECDC4", sfSymbol: "figure.run"),
        Seed(name: "Cook",     colorHex: "#FF9F43", sfSymbol: "fork.knife"),
        Seed(name: "Social",   colorHex: "#A66CFF", sfSymbol: "person.2.fill"),
        Seed(name: "Commute",  colorHex: "#8395A7", sfSymbol: "car.fill"),
        Seed(name: "Chill",    colorHex: "#26DE81", sfSymbol: "sofa.fill")
    ]

    /// Inserts the default categories if the store is empty.
    /// Safe to call on every app launch — no-op once seeded.
    @MainActor
    public static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<LogCategory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for (index, seed) in seeds.enumerated() {
            let category = LogCategory(
                name: seed.name,
                colorHex: seed.colorHex,
                sfSymbol: seed.sfSymbol,
                sortOrder: index
            )
            context.insert(category)
        }
        try? context.save()
    }
}
