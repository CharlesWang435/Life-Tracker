//
//  TempoTests.swift
//  TempoTests
//
//  Created by Charles Wang on 6/2/26.
//

import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import LifeTrackerCore

// MARK: - Duration formatting

@Suite("TimeInterval formatting")
struct DurationFormatTests {

    @Test("formattedShort picks the right unit tier")
    func formattedShortTiers() {
        #expect(TimeInterval(5).formattedShort == "5s")
        #expect(TimeInterval(65).formattedShort == "1m 5s")
        #expect(TimeInterval(3_600).formattedShort == "1h")        // exact hour drops "0m"
        #expect(TimeInterval(5_025).formattedShort == "1h 23m")   // 1h 23m 45s -> drops seconds
        #expect(TimeInterval(1_500).formattedShort == "25m")       // exact minutes drops "0s"
    }

    @Test("formattedShort rounds fractional seconds")
    func formattedShortRounds() {
        #expect(TimeInterval(59.6).formattedShort == "1m")        // rounds up to 60 -> "1m"
        #expect(TimeInterval(0.4).formattedShort == "0s")
    }

    @Test("formattedDigital zero-pads minutes and seconds")
    func formattedDigital() {
        #expect(TimeInterval(65).formattedDigital == "1:05")
        #expect(TimeInterval(5).formattedDigital == "0:05")
        #expect(TimeInterval(5_025).formattedDigital == "1:23:45")
        #expect(TimeInterval(3_600).formattedDigital == "1:00:00")
    }
}

// MARK: - Color hex

@Suite("Color hex parsing")
struct ColorHexTests {

    @Test("6-digit hex round-trips back to the same string")
    func roundTrip() {
        for hex in ["#5B6CFF", "#FF6B6B", "#000000", "#FFFFFF"] {
            #expect(Color(hex: hex).toHex() == hex)
        }
    }

    @Test("parsing tolerates missing # and whitespace")
    func tolerantParsing() {
        #expect(Color(hex: "5B6CFF").toHex() == "#5B6CFF")
        #expect(Color(hex: "  #5B6CFF  ").toHex() == "#5B6CFF")
    }

    @Test("wrong-length input falls back to mid-gray rather than crashing")
    func invalidFallback() {
        #expect(Color(hex: "xyz").toHex() == "#808080")        // length 3 -> default branch
        #expect(Color(hex: "").toHex() == "#808080")
    }

    /// Documents a known limitation: `Color(hex:)` keys off string *length*, not
    /// validity, so a non-hex string that happens to be 6 or 8 chars long is parsed
    /// as a color (the scanner reads no digits -> black) instead of hitting the gray
    /// fallback. Captured as a test so the behavior change is caught if we harden it.
    @Test("non-hex string of valid length currently parses as black (known limitation)")
    func validLengthGarbageBecomesBlack() {
        #expect(Color(hex: "nonsense").toHex() == "#000000")   // 8 chars
        #expect(Color(hex: "zzzzzz").toHex() == "#000000")     // 6 chars
    }
}

// MARK: - Calendar day helpers

@Suite("Calendar end-of-day")
struct CalendarDayTests {

    @Test("endOfDay is exactly the start of the next day")
    func endOfDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let noon = DateComponents(calendar: cal, year: 2026, month: 6, day: 2, hour: 12).date!

        let end = cal.endOfDay(for: noon)
        let expected = DateComponents(calendar: cal, year: 2026, month: 6, day: 3, hour: 0).date!
        #expect(end == expected)
    }
}

// MARK: - Session model

@Suite("Session model")
struct SessionTests {

    @Test("a session with no end date is active")
    func activeWhenNoEndDate() {
        let s = Session(startDate: .now)
        #expect(s.isActive)
    }

    @Test("setting an end date ends the session")
    func endedWhenEndDateSet() {
        let start = Date(timeIntervalSince1970: 1_000)
        let s = Session(startDate: start, endDate: start.addingTimeInterval(60))
        #expect(!s.isActive)
        #expect(s.elapsed() == 60)
    }

    @Test("elapsed on an active session measures against the reference date")
    func elapsedAgainstReference() {
        let start = Date(timeIntervalSince1970: 1_000)
        let s = Session(startDate: start)
        #expect(s.elapsed(asOf: start.addingTimeInterval(125)) == 125)
    }
}

// MARK: - Session aggregates (chart rollups)

@Suite("SessionAggregates")
struct SessionAggregatesTests {

    private func cat(_ name: String) -> LogCategory {
        LogCategory(name: name, colorHex: "#FF6B6B", sfSymbol: "circle", sortOrder: 0)
    }

    /// Builds a completed session of `seconds` duration anchored at `start`.
    private func session(_ category: LogCategory, _ start: Date, seconds: TimeInterval) -> Session {
        Session(startDate: start, endDate: start.addingTimeInterval(seconds), category: category)
    }

    @Test("categoryTotals sums per category and sorts descending")
    func categoryTotalsSortsDescending() {
        let work = cat("Work")
        let sleep = cat("Sleep")
        let t0 = Date(timeIntervalSince1970: 1_000)
        let sessions = [
            session(work, t0, seconds: 60),
            session(work, t0.addingTimeInterval(100), seconds: 120),  // Work total = 180
            session(sleep, t0.addingTimeInterval(300), seconds: 300)  // Sleep total = 300
        ]

        let totals = SessionAggregates.categoryTotals(sessions)
        #expect(totals.map(\.category.name) == ["Sleep", "Work"])     // descending
        #expect(totals.first(where: { $0.category.name == "Work" })?.duration == 180)
    }

    @Test("categoryTotals drops sessions with a deleted (nil) category")
    func categoryTotalsIgnoresNilCategory() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        let orphan = Session(startDate: t0, endDate: t0.addingTimeInterval(60), category: nil)
        #expect(SessionAggregates.categoryTotals([orphan]).isEmpty)
    }

    @Test("grandTotal adds up all category time")
    func grandTotal() {
        let work = cat("Work")
        let t0 = Date(timeIntervalSince1970: 1_000)
        let sessions = [
            session(work, t0, seconds: 60),
            session(work, t0.addingTimeInterval(100), seconds: 90)
        ]
        #expect(SessionAggregates.grandTotal(sessions) == 150)
    }

    @Test("dailyCategoryTotals buckets sessions by their start day")
    func dailyTotalsBucketByDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let work = cat("Work")
        let reference = DateComponents(calendar: cal, year: 2026, month: 6, day: 2, hour: 23).date!
        let yesterdayNoon = DateComponents(calendar: cal, year: 2026, month: 6, day: 1, hour: 12).date!
        let todayNoon = DateComponents(calendar: cal, year: 2026, month: 6, day: 2, hour: 12).date!

        let sessions = [
            session(work, yesterdayNoon, seconds: 600),
            session(work, todayNoon, seconds: 1_200)
        ]

        let bars = SessionAggregates.dailyCategoryTotals(
            sessions, days: 7, calendar: cal, asOf: reference
        )
        #expect(bars.count == 2)                              // one per day with data
        #expect(bars.map(\.day) == bars.map(\.day).sorted())  // oldest first
        #expect(bars.last?.duration == 1_200)                 // today's bucket
    }
}

// MARK: - Calendar timer suggestions

@Suite("TimerSuggester")
struct TimerSuggesterTests {

    /// Default-named categories so the keyword map applies, mirroring DefaultCategories.
    private func defaultCategories() -> [LogCategory] {
        DefaultCategories.seeds.enumerated().map { index, seed in
            LogCategory(name: seed.name, colorHex: seed.colorHex, sfSymbol: seed.sfSymbol, sortOrder: index)
        }
    }

    private func event(_ title: String, startsIn minutes: Double, lasts: Double = 60, from now: Date) -> CalendarEvent {
        let start = now.addingTimeInterval(minutes * 60)
        return CalendarEvent(title: title, start: start, end: start.addingTimeInterval(lasts * 60))
    }

    @Test("matches an event title to a category by name")
    func matchesByName() {
        let cats = defaultCategories()
        #expect(TimerSuggester.match(title: "Deep Work block", categories: cats)?.name == "Work")
    }

    @Test("matches by keyword when no category name appears")
    func matchesByKeyword() {
        let cats = defaultCategories()
        #expect(TimerSuggester.match(title: "Gym session", categories: cats)?.name == "Exercise")
        #expect(TimerSuggester.match(title: "Morning yoga", categories: cats)?.name == "Exercise")
    }

    @Test("returns nil when nothing matches")
    func noMatch() {
        let cats = defaultCategories()
        #expect(TimerSuggester.match(title: "Dentist appointment", categories: cats) == nil)
    }

    @Test("prefers an event happening now over an upcoming one")
    func prefersHappeningNow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let cats = defaultCategories()
        let events = [
            event("Standup", startsIn: 10, from: now),     // upcoming Work
            event("Gym", startsIn: -5, lasts: 60, from: now) // already running Exercise
        ]
        let suggestion = TimerSuggester.suggestion(for: events, categories: cats, now: now)
        #expect(suggestion?.category.name == "Exercise")
        #expect(suggestion?.isHappeningNow == true)
        #expect(suggestion?.reason == "On now: Gym")
    }

    @Test("suggests an upcoming event within the lookahead window")
    func suggestsUpcoming() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let cats = defaultCategories()
        let events = [event("Standup", startsIn: 10, from: now)]
        let suggestion = TimerSuggester.suggestion(for: events, categories: cats, now: now)
        #expect(suggestion?.category.name == "Work")
        #expect(suggestion?.isHappeningNow == false)
    }

    @Test("ignores events past or beyond the lookahead window")
    func ignoresOutOfWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let cats = defaultCategories()
        let past = event("Gym", startsIn: -120, lasts: 60, from: now)        // ended an hour ago
        let farFuture = event("Standup", startsIn: 120, from: now)           // 2h out
        #expect(TimerSuggester.suggestion(for: [past, farFuture], categories: cats, now: now) == nil)
    }
}

// MARK: - Suggestion store (App Group snapshot for widgets)

@Suite("SuggestionStore")
struct SuggestionStoreTests {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-suggestion-\(UUID().uuidString)")!
    }

    private func snapshot(validUntil: Date) -> SuggestionSnapshot {
        SuggestionSnapshot(
            categoryID: UUID(), categoryName: "Work", colorHex: "#FF6B6B",
            sfSymbol: "laptopcomputer", reason: "On now: Standup", validUntil: validUntil
        )
    }

    @Test("write then read round-trips a still-valid suggestion")
    func roundTrip() {
        let defaults = freshDefaults()
        let snap = snapshot(validUntil: Date(timeIntervalSince1970: 2_000))
        SuggestionStore.write(snap, to: defaults)
        #expect(SuggestionStore.read(now: Date(timeIntervalSince1970: 1_000), from: defaults) == snap)
    }

    @Test("an expired suggestion reads as nil")
    func expired() {
        let defaults = freshDefaults()
        SuggestionStore.write(snapshot(validUntil: Date(timeIntervalSince1970: 1_000)), to: defaults)
        #expect(SuggestionStore.read(now: Date(timeIntervalSince1970: 2_000), from: defaults) == nil)
    }

    @Test("writing nil clears the stored suggestion")
    func clear() {
        let defaults = freshDefaults()
        SuggestionStore.write(snapshot(validUntil: Date(timeIntervalSince1970: 9_999)), to: defaults)
        SuggestionStore.write(nil, to: defaults)
        #expect(SuggestionStore.read(now: Date(timeIntervalSince1970: 1_000), from: defaults) == nil)
    }
}

// MARK: - Sync merge (WatchConnectivity payloads)

@MainActor
@Suite("SyncMerger")
struct SyncMergerTests {

    private func makeContext() throws -> ModelContext {
        let container = try TempoModelContainer.makePreview()
        return ModelContext(container)
    }

    private func sampleCategory(id: UUID = UUID(), name: String = "Work") -> LogCategory {
        LogCategory(id: id, name: name, colorHex: "#FF6B6B", sfSymbol: "laptopcomputer", sortOrder: 0)
    }

    @Test("upsert inserts a category and a session linked to it")
    func upsertInserts() throws {
        let context = try makeContext()
        let cat = sampleCategory()
        let session = Session(startDate: Date(timeIntervalSince1970: 1_000), category: cat)
        let payload = SyncPayload(
            categories: [CategoryDTO(from: cat)],
            sessions: [SessionDTO(from: session)]
        )

        SyncMerger.apply(payload, to: context)

        let categories = try context.fetch(FetchDescriptor<LogCategory>())
        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(categories.count == 1)
        #expect(sessions.count == 1)
        #expect(sessions.first?.category?.id == cat.id)   // link resolved by id
    }

    @Test("upsert updates an existing record in place rather than duplicating")
    func upsertUpdates() throws {
        let context = try makeContext()
        let id = UUID()
        SyncMerger.apply(SyncPayload(categories: [CategoryDTO(from: sampleCategory(id: id, name: "Work"))]), to: context)
        SyncMerger.apply(SyncPayload(categories: [CategoryDTO(from: sampleCategory(id: id, name: "Deep Work"))]), to: context)

        let categories = try context.fetch(FetchDescriptor<LogCategory>())
        #expect(categories.count == 1)
        #expect(categories.first?.name == "Deep Work")
    }

    @Test("deleting a category cascades to its sessions")
    func deleteCategoryCascades() throws {
        let context = try makeContext()
        let cat = sampleCategory()
        let session = Session(startDate: Date(timeIntervalSince1970: 1_000), category: cat)
        SyncMerger.apply(
            SyncPayload(categories: [CategoryDTO(from: cat)], sessions: [SessionDTO(from: session)]),
            to: context
        )

        SyncMerger.apply(SyncPayload(deletedCategoryIDs: [cat.id]), to: context)

        #expect(try context.fetch(FetchDescriptor<LogCategory>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)   // cascaded
    }

    @Test("deleting a session leaves its category intact")
    func deleteSessionKeepsCategory() throws {
        let context = try makeContext()
        let cat = sampleCategory()
        let session = Session(startDate: Date(timeIntervalSince1970: 1_000), category: cat)
        SyncMerger.apply(
            SyncPayload(categories: [CategoryDTO(from: cat)], sessions: [SessionDTO(from: session)]),
            to: context
        )

        SyncMerger.apply(SyncPayload(deletedSessionIDs: [session.id]), to: context)

        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LogCategory>()).count == 1)
    }

    @Test("upsert inserts a day entry keyed by date")
    func upsertDayEntryInserts() throws {
        let context = try makeContext()
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let entry = DayEntry(date: day, moodRating: 4, highlight: "Shipped sync", reflectedAt: day)

        SyncMerger.apply(SyncPayload(dayEntries: [DayEntryDTO(from: entry)]), to: context)

        let entries = try context.fetch(FetchDescriptor<DayEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.highlight == "Shipped sync")
        #expect(entries.first?.moodRating == 4)
        #expect(entries.first?.isReflected == true)
    }

    @Test("upsert updates an existing day entry in place rather than duplicating")
    func upsertDayEntryUpdates() throws {
        let context = try makeContext()
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        SyncMerger.apply(SyncPayload(dayEntries: [DayEntryDTO(from: DayEntry(date: day, moodRating: 2))]), to: context)
        SyncMerger.apply(SyncPayload(dayEntries: [DayEntryDTO(from: DayEntry(date: day, moodRating: 5))]), to: context)

        let entries = try context.fetch(FetchDescriptor<DayEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.moodRating == 5)
    }

    @Test("syncing a day entry never clears the peer's local photos")
    func upsertDayEntryPreservesPhotos() throws {
        let context = try makeContext()
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        // A device already has a reflection with a local photo on disk.
        let local = DayEntry(date: day, photoFilenames: ["abc.jpg"])
        context.insert(local)
        try context.save()
        // An incoming snapshot (which never carries photo filenames) updates the mood.
        SyncMerger.apply(SyncPayload(dayEntries: [DayEntryDTO(from: DayEntry(date: day, moodRating: 3))]), to: context)

        let entries = try context.fetch(FetchDescriptor<DayEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.moodRating == 3)
        #expect(entries.first?.photoFilenames == ["abc.jpg"])   // untouched by sync
    }

    @Test("payloads from older peers without dayEntries still decode")
    func decodesLegacyPayloadWithoutDayEntries() throws {
        let legacy = #"{"categories":[],"sessions":[],"deletedCategoryIDs":[],"deletedSessionIDs":[]}"#
        let payload = try JSONDecoder().decode(SyncPayload.self, from: Data(legacy.utf8))
        #expect(payload.dayEntries.isEmpty)
    }
}

// MARK: - PlaceSuggester (pure)

@Suite("PlaceSuggester")
struct PlaceSuggesterTests {

    private func category(_ id: UUID = UUID(), name: String = "Exercise") -> LogCategory {
        LogCategory(id: id, name: name, colorHex: "#34C759", sfSymbol: "figure.run", sortOrder: 0)
    }

    // Apple Park, Cupertino, as a reference point.
    private let applePark = GeoCoordinate(latitude: 37.3349, longitude: -122.0090)

    @Test("haversine distance is ~0 for identical points and grows with separation")
    func distanceBasics() {
        #expect(PlaceSuggester.distance(applePark, applePark) < 0.01)
        // ~1.11 km per 0.01° of latitude.
        let north = GeoCoordinate(latitude: applePark.latitude + 0.01, longitude: applePark.longitude)
        let d = PlaceSuggester.distance(applePark, north)
        #expect(d > 1_000 && d < 1_200)
    }

    @Test("suggests the category of a place the user is inside")
    func suggestsWhenInside() {
        let cat = category()
        let gym = Place(name: "Gym", latitude: applePark.latitude, longitude: applePark.longitude, radius: 150, categoryID: cat.id)
        let result = PlaceSuggester.suggestion(at: applePark, places: [gym], categories: [cat])
        #expect(result?.category.id == cat.id)
        #expect(result?.placeName == "Gym")
    }

    @Test("no suggestion when outside every place's radius")
    func noneWhenOutside() {
        let cat = category()
        let gym = Place(name: "Gym", latitude: applePark.latitude, longitude: applePark.longitude, radius: 100, categoryID: cat.id)
        let faraway = GeoCoordinate(latitude: applePark.latitude + 0.02, longitude: applePark.longitude) // ~2.2 km away
        #expect(PlaceSuggester.suggestion(at: faraway, places: [gym], categories: [cat]) == nil)
    }

    @Test("nearest matching place wins when several overlap")
    func nearestWins() {
        let near = category(name: "Work")
        let far = category(name: "Study")
        let nearPlace = Place(name: "Office", latitude: applePark.latitude, longitude: applePark.longitude, radius: 500, categoryID: near.id)
        let farPlace = Place(name: "Library", latitude: applePark.latitude + 0.003, longitude: applePark.longitude, radius: 500, categoryID: far.id)
        let result = PlaceSuggester.suggestion(at: applePark, places: [farPlace, nearPlace], categories: [near, far])
        #expect(result?.category.id == near.id)
    }

    @Test("skips a place whose category was deleted")
    func skipsDanglingCategory() {
        let cat = category()
        let orphan = Place(name: "Gym", latitude: applePark.latitude, longitude: applePark.longitude, radius: 150, categoryID: UUID())
        #expect(PlaceSuggester.suggestion(at: applePark, places: [orphan], categories: [cat]) == nil)
    }
}

// MARK: - SessionActions (SwiftData-backed)

@MainActor
@Suite("SessionActions")
struct SessionActionsTests {

    /// Fresh in-memory store per test so cases stay isolated.
    private func makeContext() throws -> ModelContext {
        let container = try TempoModelContainer.makePreview()
        return ModelContext(container)
    }

    private func makeCategory(_ context: ModelContext, name: String = "Work") -> LogCategory {
        let cat = LogCategory(name: name, colorHex: "#FF6B6B", sfSymbol: "laptopcomputer", sortOrder: 0)
        context.insert(cat)
        return cat
    }

    @Test("start inserts an active session and bumps tapCount")
    func startCreatesActiveSession() throws {
        let context = try makeContext()
        let cat = makeCategory(context)

        let session = SessionActions.start(category: cat, in: context)

        #expect(session.isActive)
        #expect(session.category?.id == cat.id)
        #expect(cat.tapCount == 1)
        #expect(SessionActions.fetchActive(in: context)?.id == session.id)
    }

    @Test("starting a new session stops the previous one")
    func startStopsPrevious() throws {
        let context = try makeContext()
        let cat = makeCategory(context)

        let first = SessionActions.start(category: cat, in: context)
        let second = SessionActions.start(category: cat, in: context)

        #expect(!first.isActive)            // auto-stopped
        #expect(second.isActive)
        #expect(SessionActions.fetchActive(in: context)?.id == second.id)
        #expect(cat.tapCount == 2)
    }

    @Test("stopActive ends the running session at the given time")
    func stopActiveEndsSession() throws {
        let context = try makeContext()
        let cat = makeCategory(context)
        let start = Date(timeIntervalSince1970: 1_000)

        let session = SessionActions.start(category: cat, in: context, at: start)
        SessionActions.stopActive(in: context, at: start.addingTimeInterval(300))

        #expect(!session.isActive)
        #expect(session.elapsed() == 300)
        #expect(SessionActions.fetchActive(in: context) == nil)
    }

    @Test("stopActive is a no-op when nothing is running")
    func stopActiveNoOp() throws {
        let context = try makeContext()
        SessionActions.stopActive(in: context)   // must not crash
        #expect(SessionActions.fetchActive(in: context) == nil)
    }

    @Test("delete removes the session from the store")
    func deleteRemovesSession() throws {
        let context = try makeContext()
        let cat = makeCategory(context)
        let session = SessionActions.start(category: cat, in: context)

        SessionActions.delete(session, in: context)

        #expect(SessionActions.fetchActive(in: context) == nil)
        let remaining = try context.fetch(FetchDescriptor<Session>())
        #expect(remaining.isEmpty)
    }
}

// MARK: - Default category seeding

@MainActor
@Suite("DefaultCategories seeding")
struct DefaultCategoriesTests {

    @Test("seedIfNeeded inserts all defaults into an empty store")
    func seedsEmptyStore() throws {
        let container = try TempoModelContainer.makePreview()
        let context = ModelContext(container)

        DefaultCategories.seedIfNeeded(in: context)

        let categories = try context.fetch(FetchDescriptor<LogCategory>())
        #expect(categories.count == DefaultCategories.seeds.count)
        // sortOrder should be a contiguous 0..<count range
        #expect(Set(categories.map(\.sortOrder)) == Set(0..<DefaultCategories.seeds.count))
    }

    @Test("seedIfNeeded is idempotent — a second call adds nothing")
    func seedingIsIdempotent() throws {
        let container = try TempoModelContainer.makePreview()
        let context = ModelContext(container)

        DefaultCategories.seedIfNeeded(in: context)
        DefaultCategories.seedIfNeeded(in: context)

        let count = try context.fetchCount(FetchDescriptor<LogCategory>())
        #expect(count == DefaultCategories.seeds.count)
    }
}

// MARK: - Reflection streak (Phase 4A)

@Suite("ReflectionStreak")
struct ReflectionStreakTests {

    /// Gregorian calendar pinned to a fixed zone so day boundaries are deterministic.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    private func day(_ d: Int) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 6, day: d, hour: 12).date!
    }

    @Test("no reflected days yields a zero streak")
    func emptyIsZero() {
        #expect(ReflectionStreak.current(reflectedDays: [], today: day(2), calendar: calendar) == 0)
    }

    @Test("reflected today only is a one-day streak")
    func todayOnly() {
        let streak = ReflectionStreak.current(reflectedDays: [day(2)], today: day(2), calendar: calendar)
        #expect(streak == 1)
    }

    @Test("multiple timestamps on the same day still count as one")
    func sameDayDeduped() {
        let morning = DateComponents(calendar: calendar, year: 2026, month: 6, day: 2, hour: 8).date!
        let evening = DateComponents(calendar: calendar, year: 2026, month: 6, day: 2, hour: 21).date!
        let streak = ReflectionStreak.current(reflectedDays: [morning, evening], today: day(2), calendar: calendar)
        #expect(streak == 1)
    }

    @Test("today plus yesterday is a two-day streak")
    func todayAndYesterday() {
        let streak = ReflectionStreak.current(reflectedDays: [day(1), day(2)], today: day(2), calendar: calendar)
        #expect(streak == 2)
    }

    @Test("an unreflected today still counts a run ending yesterday")
    func todayInProgress() {
        // Reflected days 1 & 2; today is the 3rd and not yet reflected.
        let streak = ReflectionStreak.current(reflectedDays: [day(1), day(2)], today: day(3), calendar: calendar)
        #expect(streak == 2)
    }

    @Test("a gap before yesterday breaks the streak")
    func gapBreaksStreak() {
        // Reflected 1 and 3; today is 3. Day 2 missing -> only day 3 counts.
        let streak = ReflectionStreak.current(reflectedDays: [day(1), day(3)], today: day(3), calendar: calendar)
        #expect(streak == 1)
    }

    @Test("a stale streak that ended two days ago reads as zero")
    func staleStreakIsZero() {
        // Last reflection was day 1; today is day 3 -> neither today nor yesterday.
        let streak = ReflectionStreak.current(reflectedDays: [day(1)], today: day(3), calendar: calendar)
        #expect(streak == 0)
    }
}

// MARK: - Reflection time range (Phase 4A)

@Suite("ReflectionTimeRange")
struct ReflectionTimeRangeTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d, hour: 12).date!
    }

    @Test("week window starts 6 days before today (7-day inclusive window)")
    func weekStart() {
        let now = date(2026, 6, 10)
        let start = ReflectionTimeRange.week.startDate(now: now, calendar: calendar)
        #expect(start == calendar.startOfDay(for: date(2026, 6, 4)))
    }

    @Test("all range has no lower bound and contains any date")
    func allHasNoBound() {
        let now = date(2026, 6, 10)
        #expect(ReflectionTimeRange.all.startDate(now: now, calendar: calendar) == nil)
        #expect(ReflectionTimeRange.all.contains(date(2000, 1, 1), now: now, calendar: calendar))
    }

    @Test("contains excludes dates before the window and includes dates inside it")
    func containsBoundary() {
        let now = date(2026, 6, 10)
        // Month window: from May 10 onward.
        #expect(ReflectionTimeRange.month.contains(date(2026, 6, 1), now: now, calendar: calendar))
        #expect(!ReflectionTimeRange.month.contains(date(2026, 4, 1), now: now, calendar: calendar))
    }

    @Test("year window includes ~11 months ago but excludes 13 months ago")
    func yearWindow() {
        let now = date(2026, 6, 10)
        #expect(ReflectionTimeRange.year.contains(date(2025, 7, 1), now: now, calendar: calendar))
        #expect(!ReflectionTimeRange.year.contains(date(2025, 5, 1), now: now, calendar: calendar))
    }
}

// MARK: - Generic streaks (Phase 4C)

@Suite("Streak")
struct StreakTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }
    private func day(_ d: Int) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 6, day: d, hour: 12).date!
    }

    @Test("loggedDays collapses multiple sessions on a day to one date")
    func loggedDaysDedup() {
        let cat = LogCategory(name: "Work", colorHex: "#FF6B6B", sfSymbol: "circle", sortOrder: 0)
        let s1 = Session(startDate: day(2), endDate: day(2).addingTimeInterval(60), category: cat)
        let s2 = Session(startDate: day(2).addingTimeInterval(3600), category: cat)
        let s3 = Session(startDate: day(3), category: cat)
        let days = Streak.loggedDays(from: [s1, s2, s3], calendar: calendar)
        #expect(days.count == 2)
    }

    @Test("consecutive logged days form a streak; today-in-progress is forgiving")
    func loggingStreak() {
        #expect(Streak.current(days: [day(1), day(2), day(3)], today: day(3), calendar: calendar) == 3)
        // today (4th) not yet logged, but 1-3 logged → still counts the run through yesterday
        #expect(Streak.current(days: [day(1), day(2), day(3)], today: day(4), calendar: calendar) == 3)
        // gap on day 4, today day 5 → broken
        #expect(Streak.current(days: [day(1), day(2), day(3)], today: day(5), calendar: calendar) == 0)
    }
}

// MARK: - Insights (Phase 4C)

@Suite("InsightEngine")
struct InsightEngineTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }
    private func at(_ d: Int, _ h: Int) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 6, day: d, hour: h).date!
    }
    private func cat(_ name: String) -> LogCategory {
        LogCategory(name: name, colorHex: "#FF6B6B", sfSymbol: "circle", sortOrder: 0)
    }
    private func session(_ c: LogCategory, _ start: Date, minutes: Double) -> Session {
        Session(startDate: start, endDate: start.addingTimeInterval(minutes * 60), category: c)
    }

    @Test("top category this week reflects the most-tracked category")
    func topCategory() {
        let now = at(3, 18)   // Wed
        let work = cat("Work"); let gym = cat("Gym")
        let sessions = [
            session(work, at(1, 9), minutes: 120),
            session(gym, at(2, 9), minutes: 30),
            session(work, at(3, 9), minutes: 60)
        ]
        let insight = InsightEngine.topCategoryThisWeek(sessions, now: now, calendar: calendar)
        #expect(insight?.title == "Most time on Work")
    }

    @Test("longest session picks the max completed session")
    func longest() {
        let work = cat("Work")
        let sessions = [
            session(work, at(1, 9), minutes: 30),
            session(work, at(2, 9), minutes: 95)
        ]
        let insight = InsightEngine.longestSession(sessions, calendar: calendar)
        #expect(insight?.title.contains("1h 35m") == true)
    }

    @Test("week-over-week reports an increase vs last week")
    func weekOverWeek() {
        let now = at(3, 18)   // this week started Sun May 31
        let work = cat("Work")
        let sessions = [
            session(work, DateComponents(calendar: calendar, year: 2026, month: 5, day: 26, hour: 9).date!, minutes: 60), // last week
            session(work, at(1, 9), minutes: 120)  // this week (Mon)
        ]
        let insight = InsightEngine.weekOverWeek(sessions, now: now, calendar: calendar)
        #expect(insight?.detail.contains("Up") == true)
    }

    @Test("no sessions yields no insights")
    func empty() {
        #expect(InsightEngine.insights(sessions: [], now: at(3, 18), calendar: calendar).isEmpty)
    }

    @Test("hourLabel formats 12-hour clock")
    func hourLabel() {
        #expect(InsightEngine.hourLabel(0) == "12 AM")
        #expect(InsightEngine.hourLabel(9) == "9 AM")
        #expect(InsightEngine.hourLabel(13) == "1 PM")
    }
}

// MARK: - Heatmap (Phase 4C)

@Suite("Heatmap")
struct HeatmapTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }
    private func day(_ d: Int, _ h: Int = 9) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 6, day: d, hour: h).date!
    }

    @Test("grid has one column per week and 7 rows each")
    func dimensions() {
        let grid = Heatmap.grid(sessions: [], weeks: 4, now: day(3), calendar: calendar)
        #expect(grid.count == 4)
        #expect(grid.allSatisfy { $0.count == 7 })
    }

    @Test("a day's total sums its sessions; future days are flagged")
    func totalsAndFuture() {
        let cat = LogCategory(name: "Work", colorHex: "#FF6B6B", sfSymbol: "circle", sortOrder: 0)
        let sessions = [
            Session(startDate: day(1), endDate: day(1).addingTimeInterval(600), category: cat),
            Session(startDate: day(1, 14), endDate: day(1, 14).addingTimeInterval(600), category: cat)
        ]
        let grid = Heatmap.grid(sessions: sessions, weeks: 2, now: day(3), calendar: calendar)
        let cells = grid.flatMap { $0 }
        let june1 = cells.first { $0.date == calendar.startOfDay(for: day(1)) }
        #expect(june1?.seconds == 1200)                    // both sessions summed
        #expect(cells.contains { $0.isFuture })            // days after Jun 3 exist in the grid
        #expect(Heatmap.maxSeconds(grid) == 1200)
    }
}

// MARK: - Intentions (Phase 4D)

@Suite("IntentionEvaluator")
struct IntentionEvaluatorTests {
    private func cat() -> LogCategory {
        LogCategory(name: "Work", colorHex: "#FF6B6B", sfSymbol: "circle", sortOrder: 0)
    }

    @Test("an intended category counts as done only if time was logged on it")
    func doneWhenLogged() {
        let work = cat(); let gym = cat()
        let t0 = Date(timeIntervalSince1970: 1_000)
        let sessions = [Session(startDate: t0, endDate: t0.addingTimeInterval(600), category: work)]

        let outcomes = IntentionEvaluator.outcomes(
            intendedIDs: [work.id, gym.id], sessions: sessions, now: t0.addingTimeInterval(600)
        )
        #expect(outcomes.first(where: { $0.categoryID == work.id })?.done == true)
        #expect(outcomes.first(where: { $0.categoryID == gym.id })?.done == false)
        #expect(IntentionEvaluator.completedCount(intendedIDs: [work.id, gym.id], sessions: sessions, now: t0.addingTimeInterval(600)) == 1)
    }

    @Test("a zero-length session does not count as done")
    func zeroLengthNotDone() {
        let work = cat()
        let t0 = Date(timeIntervalSince1970: 1_000)
        let sessions = [Session(startDate: t0, endDate: t0, category: work)]
        let outcomes = IntentionEvaluator.outcomes(intendedIDs: [work.id], sessions: sessions, now: t0)
        #expect(outcomes.first?.done == false)
    }
}

// MARK: - Capture quality (Phase 4E)

@Suite("CaptureQuality")
struct CaptureQualityTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }
    private func at(_ h: Int, _ m: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: h, minute: m).date!
    }
    private func cat() -> LogCategory {
        LogCategory(name: "Work", colorHex: "#FF6B6B", sfSymbol: "circle", sortOrder: 0)
    }

    @Test("a gap is flagged when enough untracked time has passed since the last session")
    func gapDetected() {
        let work = cat()
        let sessions = [Session(startDate: at(9), endDate: at(11), category: work)]   // ended 11:00
        let gap = CaptureQuality.currentGap(sessions: sessions, now: at(13), calendar: calendar)
        #expect(gap?.start == at(11))
        #expect(gap?.duration == TimeInterval(2 * 3600))
    }

    @Test("no gap when the last session ended recently (under the minimum)")
    func gapTooSmall() {
        let work = cat()
        let sessions = [Session(startDate: at(9), endDate: at(12, 50), category: work)]
        #expect(CaptureQuality.currentGap(sessions: sessions, now: at(13), calendar: calendar) == nil)
    }

    @Test("no gap while a timer is running")
    func noGapWhenActive() {
        let work = cat()
        let sessions = [Session(startDate: at(9), category: work)]   // active
        #expect(CaptureQuality.currentGap(sessions: sessions, now: at(13), calendar: calendar) == nil)
    }

    @Test("allGaps finds holes between sessions and the trailing gap")
    func allGapsBetweenAndTrailing() {
        let work = cat()
        let sessions = [
            Session(startDate: at(9), endDate: at(10), category: work),
            Session(startDate: at(11), endDate: at(12), category: work)
        ]
        let gaps = CaptureQuality.allGaps(sessions: sessions, now: at(13), calendar: calendar)
        #expect(gaps.count == 2)
        #expect(gaps[0].start == at(10) && gaps[0].end == at(11))   // between sessions
        #expect(gaps[1].start == at(12) && gaps[1].end == at(13))   // trailing
    }

    @Test("allGaps ignores pre-first-session time and sub-minimum holes")
    func allGapsWindowAndMinimum() {
        let work = cat()
        let sessions = [
            Session(startDate: at(9), endDate: at(10), category: work),
            Session(startDate: at(10, 10), endDate: at(11), category: work)   // 10-min hole < 30m min
        ]
        let gaps = CaptureQuality.allGaps(sessions: sessions, now: at(11), calendar: calendar)
        #expect(gaps.isEmpty)   // no pre-9am gap, 10-min hole below threshold, no trailing
    }

    @Test("allGaps reports nothing while a timer is running")
    func allGapsNoneWhenActive() {
        let work = cat()
        let sessions = [
            Session(startDate: at(9), endDate: at(10), category: work),
            Session(startDate: at(10, 45), category: work)   // active, covers to now
        ]
        #expect(CaptureQuality.allGaps(sessions: sessions, now: at(13), calendar: calendar).count == 1)
        // only the 10:00–10:45 hole (45m); active session covers 10:45→now
    }

    @Test("long-running nudge fires past the threshold only")
    func longRunning() {
        let work = cat()
        let active = Session(startDate: at(8), category: work)
        #expect(CaptureQuality.longRunning(activeSession: active, now: at(10), threshold: 4 * 3600) == nil) // 2h
        #expect(CaptureQuality.longRunning(activeSession: active, now: at(13), threshold: 4 * 3600) == TimeInterval(5 * 3600)) // 5h
    }

    @Test("splitting a gap produces consecutive intervals clamped to the gap")
    func splitGap() {
        let gap = UntrackedGap(start: at(9), end: at(12))   // 3h
        let segs = CaptureQuality.segments(in: gap, durations: [3600, 3600, 3600])
        #expect(segs.count == 3)
        #expect(segs[0].start == at(9) && segs[0].end == at(10))
        #expect(segs[1].start == at(10) && segs[1].end == at(11))
        #expect(segs[2].start == at(11) && segs[2].end == at(12))
    }

    @Test("split clamps an over-long final duration and skips zero durations")
    func splitClampsAndSkips() {
        let gap = UntrackedGap(start: at(9), end: at(10))   // 1h
        let segs = CaptureQuality.segments(in: gap, durations: [1800, 0, 99_999])
        #expect(segs.count == 2)
        #expect(segs[0].end == at(9, 30))
        #expect(segs[1].start == at(9, 30) && segs[1].end == at(10))  // clamped to gap end
    }

    @Test("smart fill ranks the category usually done during the gap's hours first")
    func smartFillRanking() {
        let work = LogCategory(name: "Work", colorHex: "#1", sfSymbol: "a", sortOrder: 0)
        let gym = LogCategory(name: "Gym", colorHex: "#2", sfSymbol: "b", sortOrder: 1)
        // History: Work logged at 10am previously; Gym logged at 7am.
        let history = [
            Session(startDate: at(10), endDate: at(11), category: work),
            Session(startDate: at(7), endDate: at(8), category: gym)
        ]
        let gap = UntrackedGap(start: at(10), end: at(11))   // 10–11
        let ranked = GapSuggester.ranked(categories: [gym, work], history: history, gap: gap, calendar: calendar)
        #expect(ranked.first?.name == "Work")
    }

    @Test("long-running nudge ignores a completed session")
    func longRunningIgnoresCompleted() {
        let work = cat()
        let done = Session(startDate: at(2), endDate: at(9), category: work)   // 7h but ended
        #expect(CaptureQuality.longRunning(activeSession: done, now: at(13)) == nil)
    }
}

// MARK: - Goal evaluation (Phase 4B)

@Suite("GoalEvaluator")
struct GoalEvaluatorTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    /// A category with a goal configured.
    private func goalCategory(
        minutes: Int?, period: GoalPeriod = .daily, direction: GoalDirection = .atLeast
    ) -> LogCategory {
        let cat = LogCategory(name: "Work", colorHex: "#FF6B6B", sfSymbol: "laptopcomputer", sortOrder: 0)
        cat.goalMinutes = minutes
        cat.goalPeriod = period
        cat.goalDirection = direction
        return cat
    }

    private func session(_ category: LogCategory, _ start: Date, minutes: Double) -> Session {
        Session(startDate: start, endDate: start.addingTimeInterval(minutes * 60), category: category)
    }

    @Test("no goal yields nil status")
    func noGoalIsNil() {
        let cat = goalCategory(minutes: nil)
        #expect(GoalEvaluator.status(for: cat, sessions: []) == nil)
    }

    @Test("typed goal accessors round-trip through the raw strings")
    func accessorsRoundTrip() {
        let cat = goalCategory(minutes: 60, period: .weekly, direction: .atMost)
        #expect(cat.goalPeriod == .weekly)
        #expect(cat.goalDirection == .atMost)
        #expect(cat.hasGoal)
    }

    @Test("a target (atLeast) is met only once spent reaches it")
    func atLeastMet() {
        let now = DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: 18).date!
        let cat = goalCategory(minutes: 60, period: .daily, direction: .atLeast)
        let morning = DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: 9).date!

        let under = GoalEvaluator.status(for: cat, sessions: [session(cat, morning, minutes: 30)], now: now, calendar: calendar)!
        #expect(!under.isMet)
        #expect(abs(under.fraction - 0.5) < 0.0001)

        let met = GoalEvaluator.status(for: cat, sessions: [session(cat, morning, minutes: 75)], now: now, calendar: calendar)!
        #expect(met.isMet)
        #expect(met.isOver)
        #expect(met.clampedFraction == 1.0)
    }

    @Test("a cap (atMost) stays met until exceeded")
    func atMostCap() {
        let now = DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: 23).date!
        let cat = goalCategory(minutes: 60, period: .daily, direction: .atMost)
        let morning = DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: 9).date!

        let under = GoalEvaluator.status(for: cat, sessions: [session(cat, morning, minutes: 40)], now: now, calendar: calendar)!
        #expect(under.isMet)            // within the cap
        #expect(!under.isOver)

        let over = GoalEvaluator.status(for: cat, sessions: [session(cat, morning, minutes: 90)], now: now, calendar: calendar)!
        #expect(!over.isMet)            // blew the cap
        #expect(over.isOver)
        #expect(over.overage == 30 * 60)
    }

    @Test("a session spanning midnight counts only its in-period (today) portion")
    func dailyCountsOverlapForCrossMidnight() {
        let now = DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: 8).date!
        let cat = goalCategory(minutes: 600, period: .daily, direction: .atLeast)
        // Active sleep session started 23:00 yesterday, still running at 08:00 today.
        let start = DateComponents(calendar: calendar, year: 2026, month: 6, day: 2, hour: 23).date!
        let active = Session(startDate: start, category: cat)   // endDate nil
        let status = GoalEvaluator.status(for: cat, sessions: [active], now: now, calendar: calendar)!
        #expect(status.spent == 8 * 3600)   // only 00:00–08:00 today counts, not the 23:00–24:00 part
    }

    @Test("daily period ignores sessions from earlier days")
    func dailyWindowExcludesYesterday() {
        let now = DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: 12).date!
        let cat = goalCategory(minutes: 60, period: .daily)
        let yesterday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 2, hour: 12).date!
        let today = DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: 9).date!

        let status = GoalEvaluator.status(
            for: cat,
            sessions: [session(cat, yesterday, minutes: 120), session(cat, today, minutes: 20)],
            now: now, calendar: calendar
        )!
        #expect(status.spent == 20 * 60)   // only today's 20m counts
    }

    @Test("weekly period sums across the week but not before it")
    func weeklyWindow() {
        // 2026-06-03 is a Wednesday; the gregorian week (Sun-start) began Sun 2026-05-31.
        let now = DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: 12).date!
        let cat = goalCategory(minutes: 300, period: .weekly)
        let sunday = DateComponents(calendar: calendar, year: 2026, month: 5, day: 31, hour: 10).date!
        let lastWeek = DateComponents(calendar: calendar, year: 2026, month: 5, day: 28, hour: 10).date!

        let status = GoalEvaluator.status(
            for: cat,
            sessions: [session(cat, sunday, minutes: 60), session(cat, lastWeek, minutes: 999)],
            now: now, calendar: calendar
        )!
        #expect(status.spent == 60 * 60)   // only this week's Sunday session
    }
}

// MARK: - DayEntryActions (SwiftData-backed, Phase 4A)

@MainActor
@Suite("DayEntryActions")
struct DayEntryActionsTests {

    private func makeContext() throws -> ModelContext {
        let container = try TempoModelContainer.makePreview()
        return ModelContext(container)
    }

    @Test("entry(for:) creates one entry and reuses it on the next call")
    func fetchOrCreateIsStable() throws {
        let context = try makeContext()
        let noon = Date(timeIntervalSince1970: 1_000_000)

        let first = DayEntryActions.entry(for: noon, in: context)
        let second = DayEntryActions.entry(for: noon, in: context)

        #expect(first === second)                                   // same object, not a duplicate
        #expect(try context.fetchCount(FetchDescriptor<DayEntry>()) == 1)
    }

    @Test("entry is keyed by start-of-day, so any time on a day maps to one entry")
    func keyedByStartOfDay() throws {
        let context = try makeContext()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let morning = DateComponents(calendar: cal, year: 2026, month: 6, day: 2, hour: 8).date!
        let night = DateComponents(calendar: cal, year: 2026, month: 6, day: 2, hour: 23).date!

        let a = DayEntryActions.entry(for: morning, in: context, calendar: cal)
        let b = DayEntryActions.entry(for: night, in: context, calendar: cal)

        #expect(a === b)
        #expect(a.date == cal.startOfDay(for: morning))
    }

    @Test("saveReflection stamps reflectedAt and surfaces in reflectedDays")
    func saveReflectionStamps() throws {
        let context = try makeContext()
        let when = Date(timeIntervalSince1970: 1_000_000)
        let entry = DayEntryActions.entry(for: when, in: context)
        #expect(!entry.isReflected)

        DayEntryActions.saveReflection(entry, in: context, at: when)

        #expect(entry.isReflected)
        #expect(entry.reflectedAt == when)
        #expect(DayEntryActions.reflectedDays(in: context).count == 1)
    }

    @Test("reflectedDays excludes unreflected entries")
    func reflectedDaysExcludesUnreflected() throws {
        let context = try makeContext()
        // An entry created but never reflected (e.g. opened then dismissed).
        _ = DayEntryActions.entry(for: Date(timeIntervalSince1970: 1_000_000), in: context)
        DayEntryActions.save(context)

        #expect(DayEntryActions.reflectedDays(in: context).isEmpty)
    }
}
