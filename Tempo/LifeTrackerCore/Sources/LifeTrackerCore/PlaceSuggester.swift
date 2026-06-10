import Foundation

/// A plain lat/lon pair, kept free of CoreLocation so the suggester stays pure
/// and unit-testable. The app maps `CLLocation` onto this at the edge.
public struct GeoCoordinate: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A proposed timer to start because the user is physically at a tagged place.
public struct PlaceSuggestion {
    public let category: LogCategory
    public let placeName: String
    /// Distance from the user to the place centre, in metres.
    public let distance: Double

    public var reason: String { "You're at \(placeName)" }
}

/// Matches the user's current location against saved `Place`s.
///
/// Matching is deliberately simple for v1: a place matches when the user is
/// within its `radius`; among matches the nearest centre wins. Geofencing /
/// background region monitoring is a separate, larger step.
public enum PlaceSuggester {

    private static let earthRadiusMeters = 6_371_000.0

    /// Great-circle (haversine) distance between two coordinates, in metres.
    public static func distance(_ a: GeoCoordinate, _ b: GeoCoordinate) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    /// The best place suggestion for `coordinate`: the nearest place the user is
    /// inside whose `categoryID` still resolves to a live category. `nil` if none.
    public static func suggestion(
        at coordinate: GeoCoordinate,
        places: [Place],
        categories: [LogCategory]
    ) -> PlaceSuggestion? {
        let inRange = places
            .map { (place: $0, distance: distance(coordinate, GeoCoordinate(latitude: $0.latitude, longitude: $0.longitude))) }
            .filter { $0.distance <= $0.place.radius }
            .sorted { $0.distance < $1.distance }

        for candidate in inRange {
            if let category = categories.first(where: { $0.id == candidate.place.categoryID }) {
                return PlaceSuggestion(category: category, placeName: candidate.place.name, distance: candidate.distance)
            }
        }
        return nil
    }
}
