import Foundation
import SwiftData
import OSLog

private let log = Logger(subsystem: "com.charleswang.lifetracker", category: "DayEntryActions")

/// Mutations for `DayEntry`, mirroring `SessionActions`: `@MainActor` static methods
/// over a single centralised `save(_:)`. Enforces one entry per calendar day.
///
/// Note (v1 scope): `DayEntry` is intentionally NOT synced over WatchConnectivity yet —
/// reflection is a phone-first ritual. When sync is added later, extend `SyncModels`
/// with a day-keyed payload (latest `reflectedAt` wins) and apply it in `SyncMerger`.
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
    }
}
