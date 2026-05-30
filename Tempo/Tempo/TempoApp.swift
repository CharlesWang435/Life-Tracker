import SwiftUI
import SwiftData
import LifeTrackerCore

@main
struct TempoApp: App {
    let sharedContainer: ModelContainer

    init() {
        do {
            sharedContainer = try TempoModelContainer.makeShared()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    DefaultCategories.seedIfNeeded(in: sharedContainer.mainContext)
                }
        }
        .modelContainer(sharedContainer)
    }
}
