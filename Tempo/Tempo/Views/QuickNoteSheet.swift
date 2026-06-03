import SwiftUI
import SwiftData
import LifeTrackerCore

/// A lightweight one-line note prompt shown right after a session is stopped (when the
/// "note on stop" setting is on). Skippable — the note is optional.
struct QuickNoteSheet: View {
    let session: Session

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What did you work on?", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Add a note")
                } footer: {
                    if let category = session.category {
                        Text("\(category.name) · \(session.elapsed().formattedShort)")
                    }
                }
            }
            .navigationTitle("Session note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { note = session.note ?? "" }
        }
        .presentationDetents([.height(220)])
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        session.note = trimmed.isEmpty ? nil : trimmed
        SessionActions.save(context)
        dismiss()
    }
}
