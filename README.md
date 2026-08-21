# Tempo

Tempo is a life-logging iOS app built on categorical stopwatches. Tap a category when you start an activity, and Tempo silently builds a permanent, visual timeline of your day — no forms, no manual entry, no friction.

Most people can't recall at the end of the day what they did or for how long. Tempo solves that the way Screen Time solves it for your phone — but for real life: sleeping, working, studying, exercising, cooking, socialising.

<img src="Tempo%20App%20Image.png" alt="Tempo app screenshot" width="160">


## How it works

- **One tap starts a timer.** Starting a new category automatically stops whatever was running — only one timer is ever active.
- **Timestamps, not background timers.** Every session stores a `startDate` and `endDate`; elapsed time is always computed as `Date.now - startDate`. This is exactly how Apple's own Stopwatch app works, and it means tracking survives app kills, device reboots, and days spent in the background.
- **The data becomes a timeline.** Each day renders as a colour-coded, proportional timeline bar you can scroll back through, alongside per-category totals, charts, and a GitHub-style consistency heatmap.

## Features

**Core tracking**
- One-tap category start/stop with drag-to-reorder and a customizable color + SF Symbol per category
- Manual session entry and editing for backfilling missed time
- Today view with a live-updating timeline bar and running per-category totals
- History browser grouped by week, with filtering and full day detail views

**Apple Watch & widgets**
- Watch app for starting/stopping timers independently, synced to the phone via WatchConnectivity
- Watch complication showing the active category and elapsed time
- Home Screen and Lock Screen widgets (WidgetKit + App Intents) for starting timers without opening the app
- Live Activities in the Dynamic Island and on the Lock Screen while a timer runs
- Siri / App Intents shortcuts ("Hey Siri, start studying")

**Journal & media**
- Day photos, freeform notes, and mood/energy ratings attached to any day
- Evening reflection ritual: a nightly notification opens a check-in grounded in that day's actual timeline (mood, energy, one-line highlight, photo, note)

**Goals & momentum**
- Per-category goals — targets ("at least 45 min exercise") or caps ("at most 1h social media") — with daily or weekly progress rings
- Logging streaks and reflection streaks, forgiving of a single missed day
- Auto-generated insights feed ("your most productive hour is 10am," "your highest-mood days average 7.5h sleep")
- GitHub-style heatmap calendar per category or overall

**Closing the loop**
- Morning "plan today" intention-setting, compared against what actually happened that evening
- Weekly review ritual with a Sunday-evening recap of trends, goals hit, and mood arc
- Gap detection with one-tap backfill for untracked time, plus a "still running?" nudge for timers left on too long
- Location-based category suggestions: define places (e.g. "Gym," "Office") and Tempo suggests the right category on arrival

**Sync & storage**
- All data stored locally with SwiftData — no account, no server, no cloud dependency
- Categories and sessions sync between iPhone and Apple Watch over an App Group + WatchConnectivity

## Project structure

This is a multi-target Xcode project:

| Target | Description |
|---|---|
| `Tempo` | Main iPhone app |
| `Tempo Watch App` | Apple Watch app |
| `Tempo Widget` | iPhone widgets + Live Activity |
| `TempoWatchWidget` | Watch complications |
| `LifeTrackerCore` | Shared Swift package — models, sync, and pure business logic (goals, streaks, insights, heatmap, capture-quality, place suggestions) used across every target |
| `TempoTests` | Unit tests (Swift Testing) covering `LifeTrackerCore` |

## Tech stack

| Concept | Framework |
|---|---|
| UI | SwiftUI |
| Local database | SwiftData |
| State management | `@Observable` |
| Watch communication | WatchConnectivity |
| Widgets | WidgetKit + App Intents |
| Lock Screen / Dynamic Island | ActivityKit (Live Activities) |
| Charts | Swift Charts |
| Photos | PhotosUI |
| Location | Core Location (geofencing) |
| Notifications | UserNotifications |
| Testing | Swift Testing |

## Getting started

**Requirements**
- Xcode (recent version, matching the deployment target set in the project)
- An Apple ID for on-device sideloading (a paid Apple Developer account is only needed for TestFlight/App Store distribution)

**Setup**
1. Clone the repo and open `Tempo/Tempo.xcodeproj` in Xcode.
2. Select your team under Signing & Capabilities for each target (`Tempo`, `Tempo Watch App`, `Tempo Widget`, `TempoWatchWidget`).
3. Make sure the App Group capability is enabled and uses the same group identifier across all targets — this is what lets the widgets and watch app read the same data as the phone app.
4. Build and run the `Tempo` scheme on a simulator or device.

**Running tests**

```
xcodebuild test -project Tempo/Tempo.xcodeproj -scheme Tempo -destination "platform=iOS Simulator,name=iPhone 16"
```

## Architecture notes

- **No background timers.** Sessions are pure timestamp intervals (`startDate` / optional `endDate`); elapsed time is always derived, never accumulated in memory. This is the one rule the whole app is built around.
- **App Groups are required for cross-target data.** The iPhone app, widget extension, and watch app each run in separate sandboxed processes and only share data because they read from the same App Group container.
- **`LifeTrackerCore` is intentionally pure where possible.** Business logic like goal evaluation, streaks, insights, and the heatmap is implemented as testable, side-effect-free functions over plain data, separate from SwiftData and UI code.

See [`LIFE_TRACKER_SPEC.md`](LIFE_TRACKER_SPEC.md) for the full original product specification and phased build plan this project was developed against.
