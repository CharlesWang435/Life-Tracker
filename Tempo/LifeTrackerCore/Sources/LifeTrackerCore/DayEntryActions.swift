import Foundation
import SwiftData
import OSLog

private let log = Logger(subsystem: "com.charleswang.lifetracker", category: "DayEntryActions")

/// Mutations for `DayEntry`, mirroring `SessionActions`: `@MainActor` static methods
/// over a single centralised `save(_:)`. Enforces one entry per calendar day.
///
/// `DayEntry` is synced over WatchConnectivity via `SyncModels`/`SyncMerger` (keyed by
/// start-of-day `date`, last-writer-wins). Photos are NOT synced — `photoFilenames`
/// references files in each device's own documents directory, so they stay device-local.
public enum DayEntryActions {

    /// Fetch the entry for `date`'s day, or create + insert a fresh one. Never returns nil.
    @MainActor
    public static func entry(
        for date: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> DayEntry {
        let day = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<DayEntry>(
            predicate: #Predicate<DayEntry> { $0.date == day }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let entry = DayEntry(date: day)
        context.insert(entry)
        return entry
    }

    /// All days that have a completed reflection, for streak computation.
    public static func reflectedDays(in context: ModelContext) -> [Date] {
        let descriptor = FetchDescriptor<DayEntry>(
            predicate: #Predicate<DayEntry> { $0.reflectedAt != nil }
        )
        do {
            return try context.fetch(descriptor).map(\.date)
        } catch {
            log.error("reflectedDays fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Set today's (or any day's) intended categories. Creates the day entry if needed,
    /// but does NOT mark it reflected — intentions and reflection are independent.
    @MainActor
    public static func setIntentions(
        _ categoryIDs: [UUID],
        for date: Date,
        in context: ModelContext
    ) {
        let entry = entry(for: date, in: context)
        entry.intendedCategoryIDs = categoryIDs
        save(context)
    }

    /// Persist a completed reflection. Stamps `reflectedAt` (drives the streak).
    @MainActor
    public static func saveReflection(
        _ entry: DayEntry,
        in context: ModelContext,
        at date: Date = .now
    ) {
        entry.reflectedAt = date
        save(context)
    }

    /// Centralised save so we don't sprinkle `try?` across the codebase.
    @MainActor
    public static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            log.error("DayEntry save failed: \(error.localizedDescription)")
        }
        // Mirror the new state to the paired device. No-op until connectivity is
        // started/activated, and never called by SyncMerger (which saves directly),
        // so applying a remote change can't loop back out.
        #if canImport(WatchConnectivity)
        ConnectivityService.shared.broadcastState(from: context)
        #endif
    }
}
