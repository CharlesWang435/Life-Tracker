import SwiftUI
import SwiftData
import LifeTrackerCore

/// Pick up to 3 categories you intend to spend time on for `date`. Stored on the day's
/// `DayEntry.intendedCategoryIDs`. Presented as a sheet.
struct PlanTodayView: View {
    let date: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]
    @Query private var dayEntries: [DayEntry]

    @State private var selected: Set<UUID> = []

    init(date: Date) {
        self.date = date
        let day = Calendar.current.startOfDay(for: date)
        _dayEntries = Query(filter: #Predicate<DayEntry> { $0.date == day })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        let isSelected = selected.contains(category.id)
                        Button {
                            toggle(category.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.sfSymbol)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: category.colorHex))
                                    .clipShape(Circle())
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? .green : .secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Pick the categories you want to focus on today.")
                }
            }
            .navigationTitle("Plan Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                selected = Set(dayEntries.first?.intendedCategoryIDs ?? [])
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func save() {
        // Preserve category sort order in the stored list.
        let ordered = categories.filter { selected.contains($0.id) }.map(\.id)
        DayEntryActions.setIntentions(ordered, for: date, in: context)
        Haptics.success()
        dismiss()
    }
}

#Preview {
    PlanTodayView(date: .now)
        .modelContainer(try! TempoModelContainer.makePreview())
}
