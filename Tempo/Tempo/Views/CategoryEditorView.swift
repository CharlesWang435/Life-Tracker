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

    @State private var hasGoal = false
    @State private var goalHours = 1
    @State private var goalMins = 0
    @State private var goalDirection: GoalDirection = .atLeast
    @State private var goalPeriod: GoalPeriod = .daily

    /// Total goal in whole minutes, floored at 5 so a goal is never effectively zero.
    private var goalTotalMinutes: Int { max(5, goalHours * 60 + goalMins) }

    /// Upper bound for the hours wheel — a day has 24h, a week 168h.
    private var goalHourLimit: Int { goalPeriod == .daily ? 24 : 168 }

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
            Section {
                Toggle("Set a goal", isOn: $hasGoal.animation())
                if hasGoal {
                    Picker("Type", selection: $goalDirection) {
                        Text("Target").tag(GoalDirection.atLeast)
                        Text("Limit").tag(GoalDirection.atMost)
                    }
                    .pickerStyle(.segmented)

                    Picker("Period", selection: $goalPeriod) {
                        ForEach(GoalPeriod.allCases) { period in
                            Text(period.label).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: goalPeriod) { _, _ in
                        if goalHours > goalHourLimit { goalHours = goalHourLimit }
                    }

                    LabeledContent(goalDirection == .atLeast ? "At least" : "At most") {
                        Text(goalMinutesString(TimeInterval(goalTotalMinutes * 60)))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 0) {
                        Picker("Hours", selection: $goalHours) {
                            ForEach(0...goalHourLimit, id: \.self) { Text("\($0) h").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        Picker("Minutes", selection: $goalMins) {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0) m").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 120)
                }
            } header: {
                Text("Goal")
            } footer: {
                Text(goalDirection == .atLeast
                     ? "A target to reach \(goalPeriod == .daily ? "each day" : "each week")."
                     : "A cap to stay under \(goalPeriod == .daily ? "each day" : "each week").")
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
                hasGoal = category.hasGoal
                let total = category.goalMinutes ?? 60
                goalHours = total / 60
                goalMins = ((total % 60) / 5) * 5   // snap to the 5-minute wheel
                goalDirection = category.goalDirection
                goalPeriod = category.goalPeriod
            }
        }
    }

    private func save() {
        let hex = color.toHex()
        let target: LogCategory
        if let existing = category {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.colorHex = hex
            existing.sfSymbol = symbol
            target = existing
        } else {
            let new = LogCategory(
                name: name.trimmingCharacters(in: .whitespaces),
                colorHex: hex,
                sfSymbol: symbol,
                sortOrder: existingCount
            )
            context.insert(new)
            target = new
        }
        target.goalMinutes = hasGoal ? goalTotalMinutes : nil
        target.goalDirection = goalDirection
        target.goalPeriod = goalPeriod
        SessionActions.save(context)
        dismiss()
    }

    private func deleteCategory() {
        if let category {
            CategoryActions.delete(category, in: context)
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
