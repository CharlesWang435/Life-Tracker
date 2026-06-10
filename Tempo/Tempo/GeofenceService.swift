import Foundation
import CoreLocation
import SwiftData
import OSLog
import LifeTrackerCore

/// Background arrival detection: monitors saved places as CoreLocation regions and,
/// on entry, posts a "you're here — start the timer?" notification. Works while the
/// app is backgrounded or killed (iOS relaunches it for the region event), which is
/// why it's a launch-time singleton rather than view state.
///
/// Region monitoring requires **Always** authorization but NOT the background-location
/// entitlement, so it stays within a free Apple ID's limits. All sensing is on-device.
final class GeofenceService: NSObject, CLLocationManagerDelegate {
    static let shared = GeofenceService()

    /// `@AppStorage` key shared with the Settings toggle.
    static let enabledKey = "geofence.enabled"

    private let manager = CLLocationManager()
    private let log = Logger(subsystem: "com.charleswang.lifetracker", category: "Geofence")

    /// Set once at launch before any delegate callback can fire; ModelContainer is Sendable.
    nonisolated(unsafe) private var container: ModelContainer?

    private override init() { super.init() }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    var isAlwaysAuthorized: Bool { manager.authorizationStatus == .authorizedAlways }

    /// Wire up the delegate and remember the container used to resolve places on entry.
    /// Safe to call at launch (including a background relaunch for a region event).
    func start(container: ModelContainer) {
        self.container = container
        manager.delegate = self
    }

    /// Ask for Always access — required for region monitoring. iOS may first grant
    /// When-In-Use and later prompt to upgrade to Always.
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? false
    }

    /// Reconcile monitored regions with the saved places. Clears everything when the
    /// feature is off or Always access is missing.
    @MainActor
    func refresh(enabled: Bool? = nil) {
        let on = enabled ?? isEnabled
        guard on, isAlwaysAuthorized, let container else {
            stopAllMonitoring()
            return
        }

        let desired = GeofencePlanner.regions(for: PlaceActions.all(in: container.mainContext))
        let desiredIDs = Set(desired.map(\.id.uuidString))

        // Drop regions for places that were removed or trimmed out.
        for region in manager.monitoredRegions where !desiredIDs.contains(region.identifier) {
            manager.stopMonitoring(for: region)
        }
        // Add regions for newly-saved places.
        let monitoredIDs = Set(manager.monitoredRegions.map(\.identifier))
        for region in desired where !monitoredIDs.contains(region.id.uuidString) {
            let clRegion = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude),
                radius: region.radius,
                identifier: region.id.uuidString
            )
            clRegion.notifyOnEntry = true
            clRegion.notifyOnExit = false
            manager.startMonitoring(for: clRegion)
        }
        let count = manager.monitoredRegions.count
        log.debug("monitoring \(count) region(s)")
    }

    @MainActor
    private func stopAllMonitoring() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let placeID = UUID(uuidString: region.identifier) else { return }
        let container = self.container
        Task { @MainActor in
            guard let container else { return }
            handleEntry(placeID: placeID, in: container.mainContext)
        }
    }

    @MainActor
    private func handleEntry(placeID: UUID, in context: ModelContext) {
        guard let place = PlaceActions.all(in: context).first(where: { $0.id == placeID }),
              let categoryID = place.categoryID,
              let category = (try? context.fetch(FetchDescriptor<LogCategory>()))?.first(where: { $0.id == categoryID })
        else { return }

        // Don't nag if this category's timer is already running.
        if let active = SessionActions.fetchActive(in: context), active.category?.id == categoryID { return }

        PlaceArrivalNotifications.notifyArrival(
            placeName: place.name,
            categoryID: categoryID,
            categoryName: category.name
        )
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // An upgrade to Always lets us begin monitoring; reconcile against the toggle.
        Task { @MainActor in refresh() }
    }
}
