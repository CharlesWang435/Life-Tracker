import SwiftUI
import SwiftData
import LifeTrackerCore

/// The Reflect tab: an emoji trend chart (mood/energy toggle, time-range filter) over the
/// top, then a scrollable history of past daily reflections. Tapping a day edits it.
struct ReflectView: View {
    @Query(filter: #Predicate<DayEntry> { $0.reflectedAt != nil },
           sort: \DayEntry.date, order: .reverse)
    private var reflections: [DayEntry]

    @AppStorage("reflect.axis") private var axisRaw = ReflectionAxis.mood.rawValue
    @AppStorage("reflect.range") private var rangeRaw = ReflectionTimeRange.month.rawValue

    @State private var editingDay: EditingDay?
    @State private var showingDatePicker = false
    @State private var pickedDate = Date()
    @State private var pendingDate: Date?

    private var axis: ReflectionAxis { ReflectionAxis(rawValue: axisRaw) ?? .mood }
    private var range: ReflectionTimeRange { ReflectionTimeRange(rawValue: rangeRaw) ?? .month }
    private var tint: Color { axis == .mood ? .indigo : .orange }

    /// Reflections inside the selected window, newest first (for the list).
    private var inRange: [DayEntry] {
        reflections.filter { range.contains($0.date) }
    }

    /// Chart points for the selected axis, oldest first, skipping days with no rating
    /// for that axis.
    private var points: [TrendPoint] {
        inRange
            .compactMap { entry -> TrendPoint? in
                let rating = axis == .mood ? entry.moodRating : entry.energyRating
                guard let rating, let emoji = axis.emoji(for: rating) else { return nil }
                return TrendPoint(date: entry.date, rating: rating, emoji: emoji)
            }
            .sorted { $0.date < $1.date }
    }

    private var streak: Int {
        ReflectionStreak.current(reflectedDays: reflections.map(\.date))
    }

    var body: some View {
        NavigationStack {
            Group {
                if reflections.isEmpty {
                    ContentUnavailableView(
                        "No reflections yet",
                        systemImage: "moon.stars",
                        description: Text("Reflect on your day from Home or Today to start building a trend.")
                    )
                } else {
                    List {
                        Section {
                            VStack(spacing: 14) {
                                Picker("Range", selection: $rangeRaw) {
                                    ForEach(ReflectionTimeRange.allCases) { r in
                                        Text(r.label).tag(r.rawValue)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Picker("Axis", selection: $axisRaw) {
                                    ForEach(ReflectionAxis.allCases) { a in
                                        Text(a.label).tag(a.rawValue)
                                    }
                                }
                                .pickerStyle(.segmented)

                                MoodTrendChart(points: points, tint: tint)
                            }
                            .padding(.vertical, 8)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                        }

                        Section("History") {
                            if inRange.isEmpty {
                                Text("No reflections in this range.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(inRange) { entry in
                                    Button {
                                        editingDay = EditingDay(date: entry.date)
                                    } label: {
                                        ReflectionRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reflect")
            .toolbar {
                if streak > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Label("\(streak)", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        pickedDate = .now
                        showingDatePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add reflection")
                }
            }
            // Pick a date first; once the picker fully dismisses, open that day's check-in.
            .sheet(isPresented: $showingDatePicker, onDismiss: {
                if let date = pendingDate {
                    pendingDate = nil
                    editingDay = EditingDay(date: date)
                }
            }) {
                ReflectionDatePicker(selectedDate: $pickedDate) {
                    pendingDate = pickedDate
                    showingDatePicker = false
                }
            }
            .sheet(item: $editingDay) { day in
                NavigationStack { ReflectionView(date: day.date) }
            }
        }
    }
}

/// One day's reflection in the history list: date, mood + energy emoji, highlight.
private struct ReflectionRow: View {
    let entry: DayEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month().day()))
                    .font(.callout.weight(.medium))
                if let highlight = entry.highlight, !highlight.isEmpty {
                    Text(highlight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                if let mood = entry.moodRating, let e = ReflectionAxis.mood.emoji(for: mood) {
                    Text(e).font(.title3)
                }
                if let energy = entry.energyRating, let e = ReflectionAxis.energy.emoji(for: energy) {
                    Text(e).font(.title3)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

/// Wraps a day so it can drive `.sheet(item:)` without conforming `Date` to `Identifiable`.
private struct EditingDay: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Calendar date picker for choosing which day to reflect on. Future days are disabled
/// (you can't reflect on a day that hasn't happened).
private struct ReflectionDatePicker: View {
    @Binding var selectedDate: Date
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Reflection date",
                    selection: $selectedDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("Pick a date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue", action: onContinue)
                }
            }
        }
    }
}

#Preview {
    ReflectView()
        .modelContainer(try! TempoModelContainer.makePreview())
}
