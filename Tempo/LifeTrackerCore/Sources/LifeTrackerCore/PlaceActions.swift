import Foundation
import SwiftData
import OSLog

private let log = Logger(subsystem: "com.charleswang.lifetracker", category: "PlaceActions")

/// CRUD for saved `Place`s. Places are phone-only (not synced to the watch), so
/// these save with a plain `context.save()` and never broadcast.
public enum PlaceActions {

    public static func all(in context: ModelContext) -> [Place] {
        let descriptor = FetchDescriptor<Place>(sortBy: [SortDescriptor(\Place.createdAt)])
        do {
            return try context.fetch(descriptor)
        } catch {
            log.error("Place fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    @MainActor
    @discardableResult
    public static func add(
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        categoryID: UUID?,
        in context: ModelContext
    ) -> Place {
        let place = Place(
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            categoryID: categoryID
        )
        context.insert(place)
        save(context)
        return place
    }

    @MainActor
    public static func delete(_ place: Place, in context: ModelContext) {
        context.delete(place)
        save(context)
    }

    @MainActor
    public static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            log.error("Place save failed: \(error.localizedDescription)")
        }
    }
}
