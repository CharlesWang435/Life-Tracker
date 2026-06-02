//
//  TempoWatchWidget.swift
//  TempoWatchWidget
//
//  Created by Charles Wang on 6/2/26.
//

import WidgetKit
import SwiftUI
import SwiftData
import LifeTrackerCore

// MARK: - Timeline entry

/// Snapshot of what to show: either a running session or the idle prompt.
struct TempoEntry: TimelineEntry {
    let date: Date
    let active: ActiveInfo?

    struct ActiveInfo {
        let name: String
        let colorHex: String
        let symbol: String
        let startDate: Date
    }

    /// Push the active-session widget up the Smart Stack while a timer is running.
    var relevance: TimelineEntryRelevance? {
        active == nil
            ? TimelineEntryRelevance(score: 0)
            : TimelineEntryRelevance(score: 100, duration: 0)
    }
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TempoEntry {
        TempoEntry(
            date: .now,
            active: .init(name: "Work", colorHex: "#FF6B6B", symbol: "laptopcomputer", startDate: .now)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TempoEntry) -> Void) {
        completion(Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TempoEntry>) -> Void) {
        // The live elapsed time is rendered with `Text(_:style:.timer)`, which updates
        // itself every second without timeline reloads. We just need to re-read the store
        // periodically as a safety net; the app also nudges us via WidgetCenter on
        // start/stop so changes show up promptly.
        let entry = Self.currentEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// Reads the currently-active session from the shared App Group store.
    private static func currentEntry() -> TempoEntry {
        guard let container = try? TempoModelContainer.makeShared() else {
            return TempoEntry(date: .now, active: nil)
        }
        let context = ModelContext(container)
        guard let session = SessionActions.fetchActive(in: context),
              let category = session.category else {
            return TempoEntry(date: .now, active: nil)
        }
        return TempoEntry(
            date: .now,
            active: .init(
                name: category.name,
                colorHex: category.colorHex,
                symbol: category.sfSymbol,
                startDate: session.startDate
            )
        )
    }
}

// MARK: - Active session widget

struct ActiveSessionWidget: Widget {
    let kind = "TempoActiveSession"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ActiveSessionView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Active Timer")
        .description("Shows the timer you're currently running.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

private struct ActiveSessionView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TempoEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            corner
        default:
            rectangular
        }
    }

    private var color: Color {
        Color(hex: entry.active?.colorHex ?? "#808080")
    }

    // One line of text+symbol shown next to the time on a face.
    private var inline: some View {
        if let active = entry.active {
            return Label {
                Text("\(active.name) ") + Text(active.startDate, style: .timer)
            } icon: {
                Image(systemName: active.symbol)
            }
        } else {
            return Label("Start a timer", systemImage: "timer")
        }
    }

    // Small round slot — symbol over a faint ring.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let active = entry.active {
                Image(systemName: active.symbol)
                    .font(.title3)
                    .widgetAccentable()
            } else {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Curved-text corner slot.
    private var corner: some View {
        Group {
            if let active = entry.active {
                Image(systemName: active.symbol)
                    .font(.title3)
                    .widgetAccentable()
                    .widgetLabel {
                        Text(active.startDate, style: .timer)
                    }
            } else {
                Image(systemName: "timer")
                    .font(.title3)
                    .widgetLabel("Tempo")
            }
        }
    }

    // The richest slot — icon, name, and the live timer.
    private var rectangular: some View {
        Group {
            if let active = entry.active {
                HStack(spacing: 8) {
                    Image(systemName: active.symbol)
                        .font(.title3)
                        .foregroundStyle(color)
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(active.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(active.startDate, style: .timer)
                            .font(.system(.title3, design: .rounded).monospacedDigit())
                            .foregroundStyle(color)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Nothing running")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Quick-start widget (tap to open Tempo)

struct QuickStartWidget: Widget {
    let kind = "TempoQuickStart"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider()) { _ in
            QuickStartView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Open Tempo")
        .description("Tap to open Tempo and start a timer.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct QuickStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> TempoEntry { TempoEntry(date: .now, active: nil) }
    func getSnapshot(in context: Context, completion: @escaping (TempoEntry) -> Void) {
        completion(TempoEntry(date: .now, active: nil))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TempoEntry>) -> Void) {
        completion(Timeline(entries: [TempoEntry(date: .now, active: nil)], policy: .never))
    }
}

private struct QuickStartView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Tempo", systemImage: "play.circle.fill")
        case .accessoryCircular, .accessoryCorner:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .widgetAccentable()
            }
        default:
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .widgetAccentable()
                Text("Start a timer")
                    .font(.headline)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Previews

#Preview("Active", as: .accessoryRectangular) {
    ActiveSessionWidget()
} timeline: {
    TempoEntry(date: .now, active: .init(name: "Work", colorHex: "#FF6B6B", symbol: "laptopcomputer", startDate: .now.addingTimeInterval(-3_725)))
    TempoEntry(date: .now, active: nil)
}
