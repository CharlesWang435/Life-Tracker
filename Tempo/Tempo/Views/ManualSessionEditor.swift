import SwiftUI
import SwiftData
import LifeTrackerCore

struct ManualSessionEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]

    let session: Session?

    @State private var selectedCategoryID: UUID?
    @State private var startDate: Date = .now.addingTimeInterval(-3600)
    @State private var endDate: Date = .now
    @State private var hasEnded: Bool = true

    private var isEditing: Bool { session != nil }

    var body: some View {
        Form {
            Section("Category") {
                Picker("Category", selection: $selectedCategoryID) {
                    ForEach(categories) { cat in
                        Label(cat.name, systemImage: cat.sfSymbol).tag(cat.id as UUID?)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            Section("Time") {
                DatePicker("Started", selection: $startDate)
                Toggle("Has ended", isOn: $hasEnded.animation())
                if hasEnded {
                    DatePicker("Ended", selection: $endDate, in: startDate...)
                }
            }
            if isEditing {
                Section {
                    Button(role: .destructive) { deleteSession() } label: {
                        Label("Delete session", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Session" : "Add Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(selectedCategoryID == nil)
            }
            if !isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            if let session {
                selectedCategoryID = session.category?.id
                startDate = session.startDate
                hasEnded = session.endDate != nil
                endDate = session.endDate ?? .now
            } else {
                selectedCategoryID = categories.first?.id
            }
        }
    }

    private func save() {
        guard
            let id = selectedCategoryID,
            let category = categories.first(where: { $0.id == id })
        else { return }

        if let existing = session {
            existing.category = category
            existing.startDate = startDate
            existing.endDate = hasEnded ? endDate : nil
        } else {
            let new = Session(
                startDate: startDate,
                endDate: hasEnded ? endDate : nil,
                category: category
            )
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }

    private func deleteSession() {
        if let session {
            context.delete(session)
            try? context.save()
        }
        dismiss()
    }
}
