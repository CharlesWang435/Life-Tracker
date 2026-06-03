# Life Tracker App — Project Specification

## Concept

A life-logging iOS app built on categorical stopwatches. The user taps to start a category when they begin an activity, and the app silently logs their day — building a permanent, visual timeline they can always look back on.

**The core problem:** People spend each day working and relaxing but can't recall at the end of the day what they did or for how long.

**The solution:** Zero-friction one-tap logging. The data writes itself as you live your day. Think of it like Apple's Screen Time feature, but for real-world life activities — sleeping, cooking, studying, working out, socialising — not just app usage.

**App name candidates:** Tempo, Slice, Chronicle (not yet decided)

---

## Developer Background

- First iOS app — developer has Android / Android Studio experience
- Use Swift and SwiftUI (modern Apple stack, equivalent to Kotlin + Jetpack Compose)
- Target iOS 17+ and watchOS 10+ to use SwiftData and the latest APIs
- Testing approach: Xcode Simulator (free) + free Apple ID sideloading during development; Apple Developer account ($99/year) only needed when ready to submit to the App Store or send TestFlight builds

---

## Platform Targets

This is a multi-target Xcode project with four components:

| Target | Description |
|---|---|
| `LifeTracker` | Main iPhone app — full feature set |
| `LifeTracker Watch App` | Apple Watch app — streamlined start/stop UI |
| `LifeTracker Widget Extension` | iPhone widgets + Live Activity (same extension target) |
| `LifeTrackerCore` | Shared Swift package — models and data logic used by all three targets |

---

## Tech Stack

| Concept | Framework | Android Equivalent |
|---|---|---|
| UI | SwiftUI | Jetpack Compose |
| Local database | SwiftData (`@Model`, `@Query`) | Room + DAO |
| State management | `@Observable` (iOS 17) | ViewModel + StateFlow |
| Simple persistence | `UserDefaults` / `@AppStorage` | SharedPreferences |
| Watch communication | WatchConnectivity | Wear Data Layer API |
| Widgets | WidgetKit + App Intents | Glance Widgets |
| Lock Screen / Dynamic Island | ActivityKit (Live Activities) | N/A |
| Charts | Swift Charts (iOS 16+) | MPAndroidChart / Compose Charts |
| Photos | PhotosUI (`PhotosPicker`) | MediaStore API |
| Notifications | UserNotifications | WorkManager / NotificationManager |
| Package manager | Swift Package Manager | Gradle |
| Device testing | Xcode Simulator + free sideload | Android Emulator + USB debug |
| Beta distribution | TestFlight | Google Play internal testing |
| Store submission | App Store Connect | Google Play Console |

---

## Critical Architecture Decision — Timestamps, Not Background Timers

**iOS aggressively kills background processes. Never attempt to keep a timer running in the background.**

The correct approach:
- When a timer starts, save the `startDate` (a `Date` timestamp) to SwiftData
- Elapsed time is always computed as `Date.now - startDate`
- When a timer stops, save the `endDate`
- This survives app kills, device restarts, and reboots — exactly how Apple's own Clock/Stopwatch app works

```swift
// Session model
@Model class Session {
    var startDate: Date
    var endDate: Date?   // nil = currently active/running
    var category: Category
}

// Compute elapsed time anywhere
var elapsed: TimeInterval {
    (endDate ?? Date()).timeIntervalSince(startDate)
}
```

---

## Critical Setup — App Groups

The iPhone app, Widget Extension, and Watch app each run in **separate sandboxed processes**. They cannot access each other's data by default.

**App Groups** give them a shared container so they all read from the same SwiftData store and can see the active timer state.

- Configure App Groups in Xcode under each target's Signing & Capabilities
- Use the same group identifier across all three targets (e.g. `group.com.yourname.lifetracker`)
- Pass the App Group container URL when initialising the SwiftData `ModelContainer`

Without App Groups, widgets will not be able to display the current timer state.

---

## Data Models

### Category
```swift
@Model class Category {
    var id: UUID
    var name: String
    var colorHex: String       // e.g. "#FF6B6B"
    var sfSymbol: String       // SF Symbol name e.g. "book.fill"
    var sortOrder: Int
    var createdAt: Date

    // Phase 4 — Goals / budgets
    var goalMinutes: Int?              // nil = no goal set for this category
    var goalPeriod: GoalPeriod         // .daily or .weekly
    var goalDirection: GoalDirection   // .atLeast (a target) or .atMost (a cap)

    @Relationship(deleteRule: .cascade) var sessions: [Session]
}

enum GoalPeriod: String, Codable { case daily, weekly }
enum GoalDirection: String, Codable { case atLeast, atMost }
```

> **Implementation note:** the live model class is named `LogCategory` (not `Category`) to avoid a collision with the Objective-C `Category` typedef. New fields should be added there. It already carries a `tapCount: Int` used for frequency-based ordering and suggestions.

### Session
```swift
@Model class Session {
    var id: UUID
    var startDate: Date
    var endDate: Date?          // nil = currently active
    var category: Category
    var note: String?           // Phase 3
}
```

### DayEntry (Phase 3 + Phase 4)
```swift
@Model class DayEntry {
    var date: Date              // start of day, used as key
    var note: String?           // freeform journal entry
    var moodRating: Int?        // 1–5
    var photoFilenames: [String] // stored in app's documents directory

    // Phase 4 — Reflection ritual
    var highlight: String?      // one-line "highlight of the day"
    var energyRating: Int?      // 1–5, optional second axis alongside mood
    var reflectedAt: Date?      // when the evening check-in was completed (drives the "reflection streak")

    // Phase 4 — Morning intention
    var intendedCategoryIDs: [UUID]  // 1–3 categories the user planned to spend time on today
}
```

---

## Feature List by Phase

### Phase 1 — iPhone MVP (build this first)

**Category management**
- Create, edit, delete categories
- Custom name, color (color picker), and icon (SF Symbols picker)
- Drag to reorder
- Default categories pre-loaded on first launch: Sleep, Work, Study, Exercise, Cook, Social, Commute, Chill

**Logging / stopwatch**
- One-tap start on a category card
- Only one timer active at a time — tapping a new category auto-stops the current one
- Timestamp-based (see architecture decision above)
- Running elapsed time displayed while active (updates every second using a `Timer` publisher or `TimelineView`)
- Manual session entry — add a past session with custom start/end time
- Manual session edit — correct a session's start/end time or delete it

**Day view**
- Visual horizontal timeline bar for today showing colour-coded blocks proportional to time spent
- List of today's sessions with category, start time, end time, duration
- Running total per category for the day

**History browser**
- List of past days, grouped by week
- Tap any day to see its full timeline and session list
- Filter/search by category or date range

**Data persistence**
- All data stored locally with SwiftData
- Data must persist across app restarts and device reboots
- No iCloud sync in Phase 1 (local only)

---

### Phase 2 — Apple Watch + Widgets

**Apple Watch app**
- Scrollable list of categories — tap to start/stop
- Only one active timer at a time (synced with iPhone)
- Active timer view: shows category name, colour, and elapsed time
- Today summary: list of completed sessions for the day
- Watch face complication: shows active category name + elapsed time, tap to open Watch app
- WatchConnectivity sync: use `sendMessage` when both devices are reachable, `updateApplicationContext` as fallback
- Watch app should work independently if iPhone is not nearby (syncs when reconnected)

**iPhone widgets (WidgetKit)**
- Small widget: active category + elapsed time, or "Nothing running" if idle
- Medium widget: quick-launch grid of favourite categories (interactive via App Intents)
- Large widget: today's timeline
- Lock Screen widget: active category name + elapsed time
- All widgets use App Intents (iOS 17) for interactivity — user can start a category directly from the widget without opening the app

**Live Activities (ActivityKit)**
- When a timer starts, launch a Live Activity
- Shows on the Lock Screen: category icon + name + elapsed time (live updating)
- Shows in the Dynamic Island (compact and expanded states)
- Stops when the timer is stopped
- This is a defining UX feature — users never need to open the app to check what's running

**Countdown timer mode**
- Optional per-session: user sets a target duration
- App schedules a local notification when time is up
- Live Activity and widget show remaining time instead of elapsed time when in countdown mode

---

### Phase 3 — Media, Journal, Analytics

**Day photos**
- Attach photos to a specific day
- Pick from photo library (`PhotosPicker`) or capture in-app (camera)
- Photos shown in a horizontal scroll alongside the day's timeline
- Store photo files in the app's documents directory; store filenames in `DayEntry`

**Day notes and mood**
- Freeform text note per day
- Optional mood/energy rating (1–5 scale, shown as emoji or icons)

**Analytics screen**
- Weekly and monthly breakdowns using Swift Charts
- Bar chart: time per category per day over selected period
- Donut chart: category breakdown as percentage of tracked time
- Streak tracking: consecutive days with at least N minutes logged
- Day-of-week patterns: average time per category by weekday

---

### Phase 4 — Daily Engagement Loop

> **Product thesis:** Phases 1–3 make Tempo excellent at *capturing* and *visualising* the past — a beautiful rear-view mirror. But a logging app you only consult is one you eventually stop opening. The apps people open every day (Apple Fitness, Streaks, Day One, Gentler Streak) all close a loop: **intend in the morning → capture during the day → reflect at night → feel something about the week.** Phase 4 builds that loop. Every feature here is designed to cross-reference the others ("your best-rated days average 7.5h sleep") so the app feels like it *knows your life* — that is what earns a daily open.
>
> **Constraints honoured:** every Phase 4 feature is 100% on-device, needs no paid Apple Developer account, and fits the existing timestamp / SwiftData / App Group architecture. Notifications use `UserNotifications` (no special entitlement). Nothing here requires CloudKit.

The loop has four moments. Build in priority order within the phase.

#### 🌙 4A. Evening reflection ritual — *highest-priority daily hook*

The feature that turns a *time* tracker into a *life* tracker. Elevate `DayEntry` from "a few fields" into a nightly ritual.

- **Trigger:** a local notification (default 8pm, user-configurable) — "How was your day?" — that deep-links straight into a one-screen check-in.
- **Check-in screen** (single scroll, <30 seconds to complete):
  - Mood 1–5 (emoji or icon row) + optional energy 1–5
  - One-line "highlight of the day" text field
  - Optional photo (`PhotosPicker` or camera) — reuses Phase 3 day-photo storage
  - Freeform note (optional)
- **Grounded in real data:** show today's timeline bar + headline totals *above* the inputs ("You slept 6h and worked 9h — how did today feel?"). Reflection anchored to actual data is far stickier than a blank journal box.
- **Sets `reflectedAt`** — this powers the "reflection streak."
- **Payoff over time:** mood-vs-time correlations surface in the Insights feed (4C) — "your highest-mood days average 7.5h sleep," "days you exercised rate ~1 point higher."

#### 🎯 4B. Goals / budgets + progress rings — *Activity rings for your life*

Gives the user a reason to open Tempo *during* the day, not only after it.

- Optional per-category target (`goalMinutes`, `goalPeriod`, `goalDirection`) set in the category editor.
- Two directions: **targets** ("at least 45 min exercise") and **caps** ("at most 8h work," "at most 1h social media").
- **Progress rings / bars** on the Today screen showing live progress (e.g. Sleep 6/8h, Exercise 20/45min). Caps turn warning-coloured as they approach/exceed.
- Small model change, large motivational payoff — this is the in-the-moment engagement surface.

#### 🔥 4C. Streaks, momentum & the Insights feed

Two of the most proven daily-return mechanics, plus the "something new every day" surface.

**Streaks**
- Track multiple streaks: days logged in a row, days a sleep/exercise goal was hit, days with a completed reflection.
- Surface on Today and as a **watch complication**. (Builds on the existing `tapCount`/complication infrastructure.)
- Use gentle, forgiving framing (a single missed day shouldn't feel punishing) — model after Gentler Streak rather than hard "you broke it" mechanics.

**Insights feed** (auto-generated stat cards that change each visit — the daily dopamine, like a personal Spotify Wrapped served continuously)
- "You've logged 3h more Study this week than last."
- "Your most productive hour is 10am."
- "Longest focus session: 2h14m on Tuesday."
- "Your highest-mood days average 7.5h sleep." (cross-references 4A)
- Implemented as a pure, testable engine in `LifeTrackerCore` that takes sessions + day entries and emits a ranked list of insight cards; the UI just renders the top N.

**Heatmap calendar**
- GitHub-style contribution grid, per category or overall — instantly readable consistency, and visually striking.

#### 🌅 4D. Morning intention (lightweight)

Closes the loop and gives the evening reflection something concrete to react to.

- A "Plan today" strip on the Today screen: pick 1–3 categories you intend to spend time on (stored in `DayEntry.intendedCategoryIDs`).
- At night, the reflection screen compares **intended vs actual** ("You planned Study + Exercise — you did Study, missed Exercise").

#### 🔔 4E. Capture quality & friction reducers

Reflection and visualisation are only as good as the underlying data. Close the gaps that produce holes and garbage.

- **Gap detection / backfill:** "You stopped Work at 3pm; it's now 5pm — what were you doing?" with one-tap backfill into a category. The #1 source of holes in time trackers.
- **"Still running?" nudge:** if a timer has run unusually long (e.g. 4+ hours, or well past that category's typical session length), gently confirm — prevents "fell asleep with Work running" garbage data.
- **Quick note on stop:** optional one-line "what did you work on?" when a session ends, feeding the day's story and the reflection screen.
- **Siri / App Intents shortcuts:** "Hey Siri, start studying." Cheap given App Intents are already used for widgets; a genuine daily-use surface. (Also listed in Backlog — promoted here.)

#### 📅 4F. Weekly review ritual

The Phase 3 analytics screen, reframed as a *ritual* rather than a static screen.

- A **Sunday-evening notification** → a dedicated weekly recap: day-of-week patterns, category trends, this-week-vs-last, goals hit, mood arc across the week, top highlights pulled from daily reflections.
- This is the larger-cadence companion to the nightly check-in — it makes the week *feel* like something, the way the daily ritual makes the day feel like something.

#### Phase 4 build priority

| Order | Feature | Rationale | Effort |
|---|---|---|---|
| 1 | 4A Evening reflection ritual | Defines Tempo as a *life* tracker; biggest daily hook; model already specced | Low–Med |
| 2 | 4B Goals / budgets + rings | Reason to open *during* the day | Med |
| 3 | 4C Streaks | Cheapest proven retention mechanic | Low |
| 4 | 4C Insights feed | "Something new every day" | Med |
| 5 | 4A/4F Reflection + weekly notifications | The trigger that actually brings users back | Low–Med |
| 6 | 4C Heatmap calendar | Beautiful, readable consistency | Med |
| 7 | 4E Capture quality (gap detection, "still running?", quick note) | Data completeness | Med |
| 8 | 4D Morning intention | Closes the loop | Low–Med |
| 9 | 4F Weekly review ritual | Larger-cadence depth | Med |

---

### Future / Backlog

- Screen Time integration — pull Apple Screen Time data to auto-populate phone/social media sessions
- iCloud sync via CloudKit so data syncs across devices (needs paid Apple Developer account)
- Siri Shortcuts — "Hey Siri, start studying" *(promoted into Phase 4E)*
- CSV/PDF export for a date range
- Sharing a day summary as an image (pairs well with the Phase 4F weekly review)

---

## Xcode Project Setup Instructions

1. Open Xcode → New Project → iOS → App
2. Set interface to SwiftUI, storage to SwiftData
3. Add Watch App target: File → New → Target → watchOS → Watch App
4. Add Widget Extension target: File → New → Target → iOS → Widget Extension (check "Include Live Activity")
5. Add a new Swift Package for shared code (`LifeTrackerCore`) or use a shared group folder
6. Enable App Groups capability on all three targets with the same group ID
7. Set minimum deployment target: iOS 17.0, watchOS 10.0

---

## Recommended Build Order (for Claude Code sessions)

1. `LifeTrackerCore` — define `Category` and `Session` SwiftData models
2. `ModelContainer` setup with App Groups container URL
3. Category list screen — display, add, edit, delete, reorder
4. Category detail / editor — name, color picker, SF Symbol picker
5. Home screen — category grid with one-tap start/stop
6. Active timer view — elapsed time display, stop button
7. Today timeline view — visual bar + session list
8. History browser — past days list and day detail view
9. Manual session entry and edit sheet
10. Default categories seeded on first launch
11. *(Phase 2)* WatchConnectivity manager
12. *(Phase 2)* Watch app UI
13. *(Phase 2)* WidgetKit extension + App Intents
14. *(Phase 2)* Live Activity with ActivityKit
15. *(Phase 3)* Analytics screen with Swift Charts
16. *(Phase 3)* Photos and notes
17. *(Phase 4A)* Evening reflection check-in screen + 8pm notification (mood, energy, highlight, photo, note → `reflectedAt`)
18. *(Phase 4B)* Per-category goals/caps + Today progress rings
19. *(Phase 4C)* Streak engine + Today/complication surfacing
20. *(Phase 4C)* Insights engine in `LifeTrackerCore` + Insights feed UI
21. *(Phase 4C)* Heatmap calendar view
22. *(Phase 4D)* Morning "Plan today" intention strip + intended-vs-actual in reflection
23. *(Phase 4E)* Gap detection / backfill, "still running?" nudge, quick note on stop, Siri App Intents
24. *(Phase 4F)* Weekly review screen + Sunday-evening notification

---

## Key iOS Concepts to Know (from an Android Background)

- **SwiftUI views are structs**, not classes — they are lightweight and recreated constantly; put state and logic in `@Observable` classes
- **Optionals** use `if let` / `guard let` (similar to Kotlin's `?.` null safety)
- **SF Symbols** is Apple's built-in icon library — thousands of icons available, referenced by string name (e.g. `"book.fill"`, `"moon.zzz.fill"`)
- **`TimelineView`** is the SwiftUI way to drive a view that updates on a schedule (e.g. a live timer display) — use `.everyMinute` or a custom schedule
- **Previews** in SwiftUI (`#Preview`) work like Compose Previews — live in Xcode without running the simulator
- **`@AppStorage`** is a property wrapper that reads/writes a `UserDefaults` key directly in a SwiftUI view
- **`.sheet`**, **`.navigationDestination`**, and **`.fullScreenCover`** are the SwiftUI navigation and modal presentation APIs

---

## Phase 4A — Implementation Detail (Evening Reflection Ritual)

This is the build-ready spec for the first Phase 4 feature. It follows the conventions already in the codebase:
- **Pure/shared logic** (models, fetch-or-create, streak math) lives in the `LifeTrackerCore` package.
- **Data mutations** go through a `public enum …Actions` with `@MainActor` static methods and a single centralised `save(_:)` — mirroring `SessionActions`.
- **UI + platform APIs** (UserNotifications) live in the `Tempo` app target.
- **Preferences** use `@AppStorage`.

### User flow

1. At the user's chosen time (default **8:00pm**), a local notification fires: *"How was your day? — Take 30 seconds to reflect on today."*
2. Tapping it opens Tempo directly into the **Reflection** screen for *today* (deep link).
3. The screen shows **today's timeline bar + headline totals at the top** (reflection grounded in real data), then the inputs: mood (1–5), energy (1–5, optional), one-line highlight, optional photo, optional note.
4. Saving stamps `reflectedAt = .now`, which feeds the **reflection streak**.
5. The screen is also reachable any time from a **card on the Today screen** ("Reflect on today" → or, once done, a compact summary showing the mood + highlight).

### Step 1 — `DayEntry` model (LifeTrackerCore)

New file `Sources/LifeTrackerCore/DayEntry.swift`. `date` is the **start-of-day key** — exactly one entry per calendar day.

```swift
import Foundation
import SwiftData

@Model
public final class DayEntry {
    /// Start-of-day; the unique key for the day. Enforced in code via fetch-or-create.
    public var date: Date
    public var note: String?
    public var moodRating: Int?       // 1–5
    public var energyRating: Int?     // 1–5
    public var highlight: String?     // one-line "highlight of the day"
    public var photoFilenames: [String] = []   // files in the app's documents dir
    public var intendedCategoryIDs: [UUID] = [] // Phase 4D; harmless to add now
    public var reflectedAt: Date?     // set when the evening check-in is completed

    public init(date: Date) {
        self.date = date
    }

    /// True once the user has completed a reflection for this day.
    public var isReflected: Bool { reflectedAt != nil }
}
```

> **Why optional ratings:** a day with no reflection has `nil` mood — distinct from a "1" rating. `isReflected` keys off `reflectedAt`, not mood, so a user can reflect with just a note.

### Step 2 — Register the model in the schema

`DayEntry` must be added to the shared schema or `@Query`/`fetch` will crash. In `ModelContainer+Tempo.swift`:

```swift
public static let schema = Schema([
    LogCategory.self,
    Session.self,
    DayEntry.self          // ← add
])
```

> **Migration note:** since the store is local SwiftData and you're only *adding* a new model + new optional properties (no renames/required fields), this is a lightweight automatic migration — existing data is preserved. No `VersionedSchema` needed yet.

### Step 3 — `DayEntryActions` (LifeTrackerCore)

New file `Sources/LifeTrackerCore/DayEntryActions.swift`, mirroring `SessionActions` (centralised `save`, `@MainActor`). Fetch-or-create enforces one entry per day.

```swift
import Foundation
import SwiftData
import OSLog

private let log = Logger(subsystem: "com.charleswang.lifetracker", category: "DayEntryActions")

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
        if let existing = try? context.fetch(descriptor).first { return existing }
        let entry = DayEntry(date: day)
        context.insert(entry)
        return entry
    }

    /// Save a completed reflection. Stamps `reflectedAt` (drives the streak).
    @MainActor
    public static func saveReflection(
        _ entry: DayEntry,
        in context: ModelContext,
        at date: Date = .now
    ) {
        entry.reflectedAt = date
        save(context)
    }

    @MainActor
    public static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            log.error("DayEntry save failed: \(error.localizedDescription)")
        }
    }
}
```

> **Sync (v1 scope):** the existing `ConnectivityService`/`SyncMerger` sync `LogCategory` + `Session` only. `DayEntry` is **not** synced in 4A — reflection is naturally phone-centric, and leaving it out avoids touching `SyncModels` now. Note it as a known limit. When you do add it later, extend `SyncModels` with a `DayEntryPayload` (key by start-of-day `date`, latest-`reflectedAt` wins) and handle it in `SyncMerger`.

### Step 4 — Reflection streak (pure, testable)

New file `Sources/LifeTrackerCore/ReflectionStreak.swift`. Pure function over the set of reflected days — unit-testable with no SwiftData.

```swift
import Foundation

public enum ReflectionStreak {
    /// Current run of consecutive reflected days ending today (or yesterday — so an
    /// unreflected-but-not-yet-over today doesn't reset the streak to 0).
    public static func current(
        reflectedDays: [Date],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let days = Set(reflectedDays.map { calendar.startOfDay(for: $0) })
        let startOfToday = calendar.startOfDay(for: today)
        // Anchor: today if reflected, else yesterday (today is still "in progress").
        var cursor = days.contains(startOfToday)
            ? startOfToday
            : calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }
}
```

Tests (in `TempoTests` or a core test target, following the existing 6-test `TimerSuggester` pattern): empty → 0; reflected today only → 1; today + yesterday → 2; gap breaks it; unreflected today but reflected yesterday → still counts yesterday's run.

### Step 5 — Notification scheduling (Tempo app target)

New file `Tempo/ReflectionNotifications.swift`. Uses `UserNotifications` (no special entitlement). A **daily repeating** notification at the user's chosen hour/minute.

```swift
import Foundation
import UserNotifications

enum ReflectionNotifications {
    static let identifier = "tempo.reflection.daily"
    static let deepLinkID = "reflection"   // matched on tap to route into the screen

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    /// (Re)schedule the daily reminder for the given hour/minute. Pass enabled=false to cancel.
    static func reschedule(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "How was your day?"
        content.body = "Take 30 seconds to reflect on today."
        content.userInfo = ["deepLink": deepLinkID]

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
```

**Wiring in `TempoApp`:** request authorization and schedule on launch; route taps via a `UNUserNotificationCenterDelegate`. Use a small `@Observable` router so the tap flips a flag the Today screen observes.

```swift
@Observable final class AppRouter {
    var showReflectionForToday = false
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let router: AppRouter
    init(router: AppRouter) { self.router = router }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        if response.notification.request.content.userInfo["deepLink"] as? String
            == ReflectionNotifications.deepLinkID {
            await MainActor.run { router.showReflectionForToday = true }
        }
    }
    // Show banners even while the app is foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }
}
```

In `TempoApp`: hold the router + delegate, set `UNUserNotificationCenter.current().delegate`, inject the router via `.environment`, and in the `.task` block call `requestAuthorization()` then `reschedule(...)` with the stored preferences.

### Step 6 — Preferences (`@AppStorage`)

```swift
@AppStorage("reflection.enabled") var reflectionEnabled = true
@AppStorage("reflection.hour")    var reflectionHour = 20   // 8pm
@AppStorage("reflection.minute")  var reflectionMinute = 0
```

Add a small **Settings** surface (new tab or a gear in the Today toolbar) with a toggle + `DatePicker(.hourAndMinute)`. On change, call `ReflectionNotifications.reschedule(...)`. (A Settings screen doesn't exist yet — this is the natural place to introduce one; future per-feature prefs live here too.)

### Step 7 — The Reflection screen (`Tempo/Views/ReflectionView.swift`)

Grounded-in-data header (reuse `DayTimelineBar` + `CategoryTotals`, already used by `TodayView`/`DayDetailView`) above the inputs. Fetch-or-create the entry on appear; bind local `@State`, write back on save.

```swift
struct ReflectionView: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var mood: Int? = nil
    @State private var energy: Int? = nil
    @State private var highlight: String = ""
    @State private var note: String = ""
    @State private var entry: DayEntry?

    // today's sessions for the grounding header
    @Query private var sessions: [Session]
    private let dayStart: Date, dayEnd: Date

    init(date: Date) {
        self.date = date
        let cal = Calendar.current
        dayStart = cal.startOfDay(for: date)
        dayEnd = cal.endOfDay(for: date)
        let start = dayStart, end = dayEnd
        _sessions = Query(filter: #Predicate<Session> { $0.startDate >= start && $0.startDate < end },
                          sort: \Session.startDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Grounding: what actually happened today
                DayTimelineBar(sessions: sessions, dayStart: dayStart, dayEnd: dayEnd)
                CategoryTotals(sessions: sessions)

                // 2. Mood + energy (1–5 selectable icon rows)
                RatingRow(title: "Mood", selection: $mood, symbols: moodSymbols)
                RatingRow(title: "Energy", selection: $energy, symbols: energySymbols)

                // 3. Highlight + note
                TextField("Highlight of the day", text: $highlight, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                TextField("Anything else?", text: $note, axis: .vertical)
                    .lineLimit(3...6)

                // 4. Photo: PhotosPicker → save into documents dir, append to entry.photoFilenames
            }
            .padding()
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveAndDismiss() }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        let e = DayEntryActions.entry(for: date, in: context)
        entry = e
        mood = e.moodRating; energy = e.energyRating
        highlight = e.highlight ?? ""; note = e.note ?? ""
    }

    private func saveAndDismiss() {
        guard let e = entry else { return }
        e.moodRating = mood; e.energyRating = energy
        e.highlight = highlight.isEmpty ? nil : highlight
        e.note = note.isEmpty ? nil : note
        DayEntryActions.saveReflection(e, in: context)   // stamps reflectedAt
        dismiss()
    }
}
```

`RatingRow` is a small reusable 5-icon selector (filled vs outline, `.sensoryFeedback` on tap — consistent with `ActiveTimerBanner`). Mood symbols e.g. `face.dashed` → `face.smiling`; energy e.g. `battery.25` → `bolt.fill`.

**Photo storage:** save picked/captured images as JPEGs into the app's documents directory; store filenames in `entry.photoFilenames` (the Phase 3 mechanism). Render with a horizontal `ScrollView` of thumbnails.

### Step 8 — Today screen entry point

Add a `ReflectionCard` near the top of `TodayView`'s `VStack` (alongside `ActiveTimerBanner`/`SuggestionBanner`). It fetches today's `DayEntry` and shows one of two states:
- **Not yet reflected:** a prompt button "Reflect on today" + the current reflection-streak badge ("🔥 4-day streak").
- **Already reflected:** a compact summary (mood face + highlight text), tappable to edit.

Drive presentation with the `AppRouter` so the 8pm notification deep-links straight in:

```swift
.sheet(isPresented: $router.showReflectionForToday) {
    NavigationStack { ReflectionView(date: .now) }
}
```

### Build checklist (in order)

1. `DayEntry.swift` + add to `schema` (Steps 1–2)
2. `DayEntryActions.swift` (Step 3)
3. `ReflectionStreak.swift` + tests (Step 4)
4. `ReflectionNotifications.swift` + `AppRouter`/delegate wiring in `TempoApp` (Step 5)
5. `@AppStorage` prefs + minimal Settings surface (Step 6)
6. `ReflectionView.swift` + `RatingRow` (Step 7)
7. `ReflectionCard` on Today + `.sheet` deep link (Step 8)
8. Verify on simulator: schedule the notification a minute out, confirm tap → opens reflection; confirm streak increments across days (override `today:` in tests; use Xcode's date or a debug button to fast-forward for manual checks)

> **Watch:** out of scope for 4A. Reflection is a phone-first ritual. Once `DayEntry` sync lands, a watch complication could surface the streak — defer to a later pass.
