import Foundation

/// A circular region to monitor, derived from a `Place`. Kept free of CoreLocation
/// so the selection logic stays pure and unit-testable; the app maps this onto a
/// `CLCircularRegion` at the edge.
public struct MonitoredRegion: Sendable, Equatable {
    public let id: UUID
    public let latitude: Double
    public let longitude: Double
    public let radius: Double

    public init(id: UUID, latitude: Double, longitude: Double, radius: Double) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}

/// Chooses which saved places to monitor for arrival. iOS caps an app at 20
/// simultaneously-monitored regions, so the planner trims to that limit
/// (oldest places first, deterministically) and maps them to `MonitoredRegion`s.
public enum GeofencePlanner {
    /// CoreLocation's per-app limit on simultaneously monitored regions.
    public static let systemRegionLimit = 20

    public static func regions(for places: [Place], limit: Int = systemRegionLimit) -> [MonitoredRegion] {
        places
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(max(0, limit))
            .map { MonitoredRegion(id: $0.id, latitude: $0.latitude, longitude: $0.longitude, radius: $0.radius) }
    }
}
