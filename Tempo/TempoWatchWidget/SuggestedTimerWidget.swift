//
//  SuggestedTimerWidget.swift
//  TempoWatchWidget
//
//  Shows the calendar-driven timer Tempo suggests, pushed from the iPhone and
//  read from the shared App Group store. Surfaces in the Smart Stack while a
//  relevant event is on (or coming up).
//

import WidgetKit
import SwiftUI
import LifeTrackerCore

struct SuggestionEntry: TimelineEntry {
    let date: Date
    let suggestion: SuggestionSnapshot?

    /// Promote in the Smart Stack only when there's actually something to suggest.
    var relevance: TimelineEntryRelevance? {
        suggestion == nil ? TimelineEntryRelevance(score: 0) : TimelineEntryRelevance(score: 80)
    }
}

struct SuggestionProvider: TimelineProvider {
    func placeholder(in context: Context) -> SuggestionEntry {
        SuggestionEntry(date: .now, suggestion: SuggestionSnapshot(
            categoryID: UUID(), categoryName: "Exercise", colorHex: "#4ECDC4",
            sfSymbol: "figure.run", reason: "Up next: Gym", validUntil: .now.addingTimeInterval(3_600)
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (SuggestionEntry) -> Void) {
        completion(SuggestionEntry(date: .now, suggestion: SuggestionStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SuggestionEntry>) -> Void) {
        let snapshot = SuggestionStore.read()
        let entry = SuggestionEntry(date: .now, suggestion: snapshot)
        // Refresh when the current suggestion expires, or periodically if there's none.
        let next = snapshot?.validUntil ?? Date(timeIntervalSinceNow: 1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SuggestedTimerWidget: Widget {
    let kind = "TempoSuggestedTimer"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SuggestionProvider()) { entry in
            SuggestionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Suggested Timer")
        .description("A timer Tempo suggests from your calendar.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
            .accessoryCorner
        ])
    }
}

private struct SuggestionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SuggestionEntry

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

    private var color: Color { Color(hex: entry.suggestion?.colorHex ?? "#808080") }

    private var inline: some View {
        if let s = entry.suggestion {
            return Label("\(s.categoryName)?", systemImage: s.sfSymbol)
        } else {
            return Label("No suggestion", systemImage: "lightbulb")
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.suggestion?.sfSymbol ?? "lightbulb")
                .font(.title3)
                .widgetAccentable()
        }
    }

    private var corner: some View {
        Group {
            if let s = entry.suggestion {
                Image(systemName: s.sfSymbol)
                    .font(.title3)
                    .widgetAccentable()
                    .widgetLabel(s.categoryName)
            } else {
                Image(systemName: "lightbulb")
                    .font(.title3)
                    .widgetLabel("Tempo")
            }
        }
    }

    private var rectangular: some View {
        Group {
            if let s = entry.suggestion {
                HStack(spacing: 8) {
                    Image(systemName: s.sfSymbol)
                        .font(.title3)
                        .foregroundStyle(color)
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Start \(s.categoryName)?")
                            .font(.headline)
                            .lineLimit(1)
                        Text(s.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No suggestion")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
