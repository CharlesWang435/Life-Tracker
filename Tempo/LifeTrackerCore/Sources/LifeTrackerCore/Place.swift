import Foundation
import SwiftData

/// A saved location associated with a category, used for arrival-based timer
/// suggestions ("you're at the Gym → start Exercise?"). Stored on-device only;
/// raw coordinates never leave the phone.
///
/// `Place` is intentionally NOT synced over WatchConnectivity — location is
/// sensed and matched on the phone, which then pushes the resulting suggestion
/// (a `SuggestionSnapshot`) to the watch like the calendar flow does.
@Model
public final class Place {
    public var id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    /// Match radius in metres. The user is "at" this place when within it.
    public var radius: Double
    /// The category to suggest when the user arrives here.
    public var categoryID: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 120,
        categoryID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.categoryID = categoryID
        self.createdAt = createdAt
    }
}
