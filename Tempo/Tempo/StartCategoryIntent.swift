import AppIntents
import SwiftData
import LifeTrackerCore

/// A category exposed to Siri / Shortcuts as a pickable value (e.g. "Start studying").
struct CategoryEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Category" }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    static let defaultQuery = CategoryEntityQuery()
}

/// Resolves `CategoryEntity` values from the shared SwiftData store.
struct CategoryEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CategoryEntity] {
        try Self.all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        try Self.all()
    }

    @MainActor
    static func all() throws -> [CategoryEntity] {
        let context = ModelContext(try TempoModelContainer.makeShared())
        let categories = try context.fetch(
            FetchDescriptor<LogCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        return categories.map { CategoryEntity(id: $0.id, name: $0.name) }
    }
}

/// "Hey Siri, start studying" — starts a timer for the chosen category (auto-stopping any
/// running one), writing straight to the shared store so the app/widgets reflect it.
struct StartCategoryIntent: AppIntent {
    static var title: LocalizedStringResource { "Start a Category Timer" }
    static var description: IntentDescription {
        IntentDescription("Start tracking time for one of your categories.")
    }

    @Parameter(title: "Category")
    var category: CategoryEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(try TempoModelContainer.makeShared())
        let id = category.id
        let match = try context.fetch(
            FetchDescriptor<LogCategory>(predicate: #Predicate { $0.id == id })
        ).first
        guard let logCategory = match else {
            return .result(dialog: "I couldn't find that category.")
        }
        SessionActions.start(category: logCategory, in: context)
        return .result(dialog: "Started \(logCategory.name).")
    }
}

/// "Stop my timer" — ends the active session, if any.
struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource { "Stop the Timer" }
    static var description: IntentDescription {
        IntentDescription("Stop the currently running timer.")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(try TempoModelContainer.makeShared())
        guard let active = SessionActions.fetchActive(in: context) else {
            return .result(dialog: "Nothing is running.")
        }
        let name = active.category?.name ?? "the timer"
        SessionActions.stopActive(in: context)
        return .result(dialog: "Stopped \(name).")
    }
}

/// Registers the Siri phrases / Shortcuts actions.
struct TempoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartCategoryIntent(),
            phrases: [
                "Start \(\.$category) in \(.applicationName)",
                "Start a timer in \(.applicationName)"
            ],
            shortTitle: "Start Timer",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: StopTimerIntent(),
            phrases: [
                "Stop my \(.applicationName) timer",
                "Stop the timer in \(.applicationName)"
            ],
            shortTitle: "Stop Timer",
            systemImageName: "stop.circle"
        )
    }
}
