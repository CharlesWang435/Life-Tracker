import SwiftUI
import SwiftData
import LifeTrackerCore

/// Split an untracked gap across several categories. The gap's length is a fixed budget,
/// so the time is always fully allocated: you adjust the earlier categories and the last
/// one automatically "fills the rest". On save, one completed session per segment.
struct GapFillView: View {
    let gap: UntrackedGap

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]

    private struct Segment: Identifiable {
        let id = UUID()
        var categoryID: UUID
        var minutes: Int
    }

    @State private var segments: [Segment] = []

    private var totalMinutes: Int { Int((gap.duration / 60).rounded()) }
    private var lastIndex: Int { segments.count - 1 }

    private func category(_ id: UUID) -> LogCategory? { categories.first { $0.id == id } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Untracked", value: goalMinutesString(gap.duration))
                } footer: {
                    Text("\(gap.start.formatted(date: .omitted, time: .shortened)) – \(gap.end.formatted(date: .omitted, time: .shortened))")
                }

                Section {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        segmentRow(index: index, segment: segment)
                    }
                    .onDelete { offsets in
                        segments.remove(atOffsets: offsets)
                        normalize()
                    }

                    Menu {
                        ForEach(categories) { cat in
                            Button {
                                addCategory(cat)
                            } label: {
                                Label(cat.name, systemImage: cat.sfSymbol)
                            }
                        }
                    } label: {
                        Label("Add a category", systemImage: "plus.circle")
                    }

                    if segments.count > 1 {
                        Button("Split evenly", systemImage: "rectangle.split.3x1") {
                            splitEvenly()
                        }
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    if segments.count > 1 {
                        Text("The last category fills whatever time is left.")
                    }
                }
            }
            .navigationTitle("Fill the gap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(segments.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func segmentRow(index: Int, segment: Segment) -> some View {
        let isAutoFill = index == lastIndex && segments.count > 1
        let isSingle = segments.count == 1
        HStack(spacing: 10) {
            if let cat = category(segment.categoryID) {
                Image(systemName: cat.sfSymbol)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(hex: cat.colorHex))
                    .clipShape(Circle())
                Text(cat.name)
            }
            Spacer()
            if isAutoFill || isSingle {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(goalMinutesString(TimeInterval(segment.minutes * 60)))
                        .foregroundStyle(.secondary)
                    Text(isSingle ? "whole gap" : "fills the rest")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Stepper(
                    value: Binding(
                        get: { segment.minutes },
                        set: { setEditable(index, to: $0) }
                    ),
                    in: 0...totalMinutes,
                    step: 5
                ) {
                    Text(goalMinutesString(TimeInterval(segment.minutes * 60)))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Allocation — the budget (totalMinutes) is always fully assigned.

    /// Set an editable (non-last) segment, clamping so the last segment stays ≥ 0, then
    /// let the last segment absorb the remainder.
    private func setEditable(_ index: Int, to newValue: Int) {
        guard segments.count > 1, index != lastIndex else { return }
        let sumOtherEditable = segments.indices
            .filter { $0 != index && $0 != lastIndex }
            .reduce(0) { $0 + segments[$1].minutes }
        let maxForIndex = max(0, totalMinutes - sumOtherEditable)
        segments[index].minutes = min(max(0, newValue), maxForIndex)
        normalize()
    }

    /// Recompute the last segment as the leftover; a single segment fills the whole gap.
    private func normalize() {
        guard !segments.isEmpty else { return }
        if segments.count == 1 {
            segments[0].minutes = totalMinutes
            return
        }
        let sumOthers = segments.indices
            .filter { $0 != lastIndex }
            .reduce(0) { $0 + segments[$1].minutes }
        segments[lastIndex].minutes = max(0, totalMinutes - sumOthers)
    }

    private func addCategory(_ cat: LogCategory) {
        segments.append(Segment(categoryID: cat.id, minutes: 0))
        normalize()   // new last fills the remainder (0 if already full → reduce others to make room)
    }

    private func splitEvenly() {
        guard !segments.isEmpty else { return }
        // Nearest-5 share, reduced if rounding-up would overshoot the budget; the last
        // segment (via normalize) takes whatever's left, keeping it close to even.
        var base = Int((Double(totalMinutes) / Double(segments.count) / 5).rounded()) * 5
        while base > 0 && base * (segments.count - 1) > totalMinutes { base -= 5 }
        for index in segments.indices { segments[index].minutes = base }
        normalize()
    }

    private func save() {
        let durations = segments.map { TimeInterval($0.minutes * 60) }
        var intervals = CaptureQuality.segments(in: gap, durations: durations)
        // Whole-minute durations can leave a few unallocated seconds at the tail; extend
        // the final segment to the gap end so the gap is covered exactly.
        if !intervals.isEmpty, intervals[intervals.count - 1].end < gap.end {
            intervals[intervals.count - 1].end = gap.end
        }
        let activeCategoryIDs = segments.filter { $0.minutes > 0 }.map(\.categoryID)
        for (interval, categoryID) in zip(intervals, activeCategoryIDs) {
            guard let cat = category(categoryID) else { continue }
            SessionActions.addCompleted(category: cat, start: interval.start, end: interval.end, in: context)
        }
        Haptics.success()
        dismiss()
    }
}
