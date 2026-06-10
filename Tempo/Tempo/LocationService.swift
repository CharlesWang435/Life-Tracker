import Foundation
import CoreLocation
import Observation
import LifeTrackerCore

/// Bridges CoreLocation to the pure `PlaceSuggester`: requests when-in-use
/// permission and provides the device's current coordinate on demand. Everything
/// stays on-device — no location data leaves the phone.
///
/// v1 uses foreground one-shot location (a request while the app is open), not
/// background geofencing/region monitoring — that's a larger, separate step.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private(set) var authorizationStatus: CLAuthorizationStatus
    /// The most recent fix, as a pure coordinate for the suggester.
    private(set) var currentCoordinate: GeoCoordinate?

    /// Continuations waiting on an in-flight `requestCoordinate()` call.
    private var pendingFixes: [CheckedContinuation<GeoCoordinate?, Never>] = []

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    var needsPermissionPrompt: Bool { authorizationStatus == .notDetermined }

    /// Ask iOS for when-in-use access. The result arrives via the delegate, which
    /// updates `authorizationStatus`.
    func requestAccess() {
        manager.requestWhenInUseAuthorization()
    }

    /// Request a single location fix, resolving to the coordinate (or nil on failure
    /// / not authorized). Multiple concurrent callers share one underlying request.
    func requestCoordinate() async -> GeoCoordinate? {
        guard isAuthorized else { return nil }
        return await withCheckedContinuation { continuation in
            pendingFixes.append(continuation)
            manager.requestLocation()
        }
    }

    private func resolvePending(with coordinate: GeoCoordinate?) {
        let waiters = pendingFixes
        pendingFixes.removeAll()
        for waiter in waiters { waiter.resume(returning: coordinate) }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorizationStatus = status }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = GeoCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        Task { @MainActor in
            self.currentCoordinate = coordinate
            self.resolvePending(with: coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.resolvePending(with: nil) }
    }
}
