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
        #expect(TimeInterval(3_600).formattedShort == "1h 0m")
        #expect(TimeInterval(5_025).formattedShort == "1h 23m")   // 1h 23m 45s -> drops seconds
    }

    @Test("formattedShort rounds fractional seconds")
    func formattedShortRounds() {
        #expect(TimeInterval(59.6).formattedShort == "1m 0s")     // rounds up to 60
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
