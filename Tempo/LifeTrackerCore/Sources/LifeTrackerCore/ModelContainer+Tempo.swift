import Foundation
import SwiftData

public enum TempoModelContainer {
    public static let schema = Schema([
        LogCategory.self,
        Session.self
    ])

    /// Shared container backed by the App Group so iPhone app, Watch app, and
    /// Widget extension all read/write the same SwiftData store.
    /// Falls back to the default per-app sandbox if the App Group isn't
    /// configured yet (handy during early bring-up).
    public static func makeShared() throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let groupURL = AppGroup.containerURL {
            let storeURL = groupURL.appendingPathComponent("Tempo.store")
            configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// In-memory container for SwiftUI previews and tests.
    public static func makePreview() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
