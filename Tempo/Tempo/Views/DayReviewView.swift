import SwiftUI
import SwiftData
import LifeTrackerCore

/// Whole-day gap review: lists every untracked hole in today's timeline. Each can be
/// filled with one category, or split across several. Rows disappear as they're filled.
struct DayReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]
    @Query private var todaySessions: [Session]
    @Query(sort: \Session.startDate) private var allSessions: [Session]
    @State private var splitGap: UntrackedGap?

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.endOfDay(for: .now)
        _todaySessions = Query(filter: #Predicate<Session> { $0.startDate >= start && $0.startDate < end })
    }

    private var gaps: [UntrackedGap] { CaptureQuality.allGaps(sessions: todaySessions) }
    private var totalUntracked: TimeInterval { gaps.reduce(0) { $0 + $1.duration } }

    var body: some View {
        NavigationStack {
            Group {
                if gaps.isEmpty {
                    ContentUnavailableView(
                        "Day fully tracked",
                        systemImage: "checkmark.seal",
                        description: Text("No untracked gaps in today's timeline. Nice.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(gaps) { gap in
                                GapReviewRow(
                                    gap: gap,
                                    categories: GapSuggester.ranked(categories: categories, history: allSessions, gap: gap),
                                    onFill: { fill(gap, with: $0) },
                                    onSplit: { splitGap = gap }
                                )
                            }
                        } footer: {
                            Text("\(goalMinutesString(totalUntracked)) untracked across \(gaps.count) gap\(gaps.count == 1 ? "" : "s").")
                        }
                    }
                }
            }
            .navigationTitle("Review Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $splitGap) { gap in
                GapFillView(gap: gap)
            }
        }
    }

    private func fill(_ gap: UntrackedGap, with category: LogCategory) {
        SessionActions.addCompleted(category: category, start: gap.start, end: gap.end, in: context)
        Haptics.success()
    }
}

/// One gap row: its time range + duration, with a menu to fill it with a category or split.
private struct GapReviewRow: View {
    let gap: UntrackedGap
    let categories: [LogCategory]
    let onFill: (LogCategory) -> Void
    let onSplit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(gap.start.formatted(date: .omitted, time: .shortened)) – \(gap.end.formatted(date: .omitted, time: .shortened))")
                    .font(.callout.weight(.medium))
                Text(goalMinutesString(gap.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(categories) { category in
                    Button {
                        onFill(category)
                    } label: {
                        Label(category.name, systemImage: category.sfSymbol)
                    }
                }
                if categories.count > 1 {
                    Divider()
                    Button {
                        onSplit()
                    } label: {
                        Label("Split…", systemImage: "rectangle.split.3x1")
                    }
                }
            } label: {
                Label("Fill", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
            }
        }
    }
}
