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
    @Relationship(deleteRule: .cascade) var sessions: [Session]
}
```

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

### DayEntry (Phase 3)
```swift
@Model class DayEntry {
    var date: Date              // start of day, used as key
    var note: String?
    var moodRating: Int?        // 1–5
    var photoFilenames: [String] // stored in app's documents directory
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

### Future / Backlog

- Screen Time integration — pull Apple Screen Time data to auto-populate phone/social media sessions
- iCloud sync via CloudKit so data syncs across devices
- Siri Shortcuts — "Hey Siri, start studying"
- CSV/PDF export for a date range
- Sharing a day summary as an image

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

---

## Key iOS Concepts to Know (from an Android Background)

- **SwiftUI views are structs**, not classes — they are lightweight and recreated constantly; put state and logic in `@Observable` classes
- **Optionals** use `if let` / `guard let` (similar to Kotlin's `?.` null safety)
- **SF Symbols** is Apple's built-in icon library — thousands of icons available, referenced by string name (e.g. `"book.fill"`, `"moon.zzz.fill"`)
- **`TimelineView`** is the SwiftUI way to drive a view that updates on a schedule (e.g. a live timer display) — use `.everyMinute` or a custom schedule
- **Previews** in SwiftUI (`#Preview`) work like Compose Previews — live in Xcode without running the simulator
- **`@AppStorage`** is a property wrapper that reads/writes a `UserDefaults` key directly in a SwiftUI view
- **`.sheet`**, **`.navigationDestination`**, and **`.fullScreenCover`** are the SwiftUI navigation and modal presentation APIs
