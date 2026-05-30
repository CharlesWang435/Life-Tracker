import SwiftUI
import SwiftData
import LifeTrackerCore

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let category: LogCategory?
    /// Used when creating a new category — the next sortOrder is `existingCount`.
    /// Avoids a fresh fetch inside save().
    var existingCount: Int = 0

    @State private var name: String = ""
    @State private var color: Color = .blue
    @State private var symbol: String = "tag.fill"
    @State private var showingSymbolPicker = false

    private var isEditing: Bool { category != nil }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Category name", text: $name)
            }
            Section("Color") {
                ColorPicker("Custom color", selection: $color, supportsOpacity: false)
                ColorSwatchRow(selection: $color)
            }
            Section("Icon") {
                Button {
                    showingSymbolPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(color)
                            .clipShape(Circle())
                        Text(symbol)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
            if isEditing {
                Section {
                    Button(role: .destructive) {
                        deleteCategory()
                    } label: {
                        Label("Delete category", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Category" : "New Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingSymbolPicker) {
            SFSymbolPicker(selection: $symbol)
        }
        .onAppear {
            if let category {
                name = category.name
                color = Color(hex: category.colorHex)
                symbol = category.sfSymbol
            }
        }
    }

    private func save() {
        let hex = color.toHex()
        if let existing = category {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.colorHex = hex
            existing.sfSymbol = symbol
        } else {
            let new = LogCategory(
                name: name.trimmingCharacters(in: .whitespaces),
                colorHex: hex,
                sfSymbol: symbol,
                sortOrder: existingCount
            )
            context.insert(new)
        }
        SessionActions.save(context)
        dismiss()
    }

    private func deleteCategory() {
        if let category {
            context.delete(category)
            try? context.save()
        }
        dismiss()
    }
}

struct ColorSwatchRow: View {
    @Binding var selection: Color
    private let palette: [String] = [
        "#FF6B6B", "#FF9F43", "#FFB84D", "#FFD93D",
        "#6BCB77", "#4ECDC4", "#5B6CFF", "#A66CFF",
        "#FF79C6", "#8395A7"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(palette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                        .onTapGesture { selection = Color(hex: hex) }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
