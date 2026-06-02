import Foundation
import SwiftData
import OSLog

#if canImport(WatchConnectivity)
import WatchConnectivity

/// Syncs the SwiftData store between iPhone and Watch over WatchConnectivity.
///
/// - Upserts (the full store snapshot) ride on `updateApplicationContext`: only
///   the latest matters, and the OS re-delivers it automatically when the peer
///   reconnects — perfect for "keep both devices' state the same".
/// - Deletes ride on `transferUserInfo`: queued and guaranteed, so a delete is
///   never lost (an absent record in a snapshot can't express "was deleted").
///
/// App Groups are per-device, so without this the two stores never meet. See
/// `TempoModelContainer`. Start once at launch with the shared container.
public final class ConnectivityService: NSObject {
    public static let shared = ConnectivityService()

    private let log = Logger(subsystem: "com.charleswang.lifetracker", category: "Connectivity")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Set once at startup before any delegate callback can fire; ModelContainer is Sendable.
    nonisolated(unsafe) private var container: ModelContainer?

    private override init() { super.init() }

    /// Activate the session and remember the container used to apply incoming changes.
    @MainActor
    public func start(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: Outgoing

    /// Push the whole store as the latest application context (upserts only).
    @MainActor
    public func broadcastState(from context: ModelContext) {
        guard isActivated else {
            log.notice("broadcastState skipped: WCSession not activated")
            return
        }
        send(applicationContext: SyncPayload.fullState(from: context))
    }

    /// Send explicit deletes that a snapshot can't express.
    @MainActor
    public func broadcastDeletes(categoryIDs: [UUID] = [], sessionIDs: [UUID] = []) {
        guard isActivated, !(categoryIDs.isEmpty && sessionIDs.isEmpty) else { return }
        let payload = SyncPayload(deletedCategoryIDs: categoryIDs, deletedSessionIDs: sessionIDs)
        guard let data = try? encoder.encode(payload) else { return }
        WCSession.default.transferUserInfo(["syncDelete": data])
    }

    private var isActivated: Bool {
        WCSession.isSupported() && WCSession.default.activationState == .activated
    }

    private func send(applicationContext payload: SyncPayload) {
        guard let data = try? encoder.encode(payload) else { return }
        do {
            try WCSession.default.updateApplicationContext(["syncState": data])
            log.notice("→ sent appContext: \(payload.categories.count) cats, \(payload.sessions.count) sessions")
        } catch {
            log.error("updateApplicationContext failed: \(error.localizedDescription)")
        }
    }

    // MARK: Incoming

    private func apply(_ data: Data) {
        guard let payload = try? decoder.decode(SyncPayload.self, from: data) else {
            log.error("failed to decode incoming sync payload")
            return
        }
        log.notice("applying payload: \(payload.categories.count) cats, \(payload.sessions.count) sessions, deletes \(payload.deletedCategoryIDs.count)c/\(payload.deletedSessionIDs.count)s")
        let container = self.container
        Task { @MainActor in
            guard let container else { return }
            SyncMerger.apply(payload, to: container.mainContext)
        }
    }
}

extension ConnectivityService: WCSessionDelegate {
    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error { log.error("WCSession activation: \(error.localizedDescription)") }
        #if os(iOS)
        log.notice("WC activated: state=\(activationState.rawValue) paired=\(session.isPaired) watchAppInstalled=\(session.isWatchAppInstalled) reachable=\(session.isReachable)")
        #else
        log.notice("WC activated: state=\(activationState.rawValue) companionInstalled=\(session.isCompanionAppInstalled) reachable=\(session.isReachable)")
        #endif
        // Publish our current state so the peer catches up immediately.
        let container = self.container
        Task { @MainActor in
            guard let container else { return }
            broadcastState(from: container.mainContext)
        }
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        log.notice("← received appContext")
        if let data = applicationContext["syncState"] as? Data { apply(data) }
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        log.notice("← received userInfo")
        if let data = userInfo["syncDelete"] as? Data { apply(data) }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // The phone can pair with a new watch; reactivate to keep syncing.
        session.activate()
    }
    #endif
}
#endif
