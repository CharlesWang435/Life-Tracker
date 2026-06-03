import SwiftUI
import SwiftData
import LifeTrackerCore

/// A page listing every goal with its current progress, plus the categories that don't
/// have a goal yet. Tapping any row opens the category editor to set/change its goal.
/// Presented as a sheet from the Today Goals strip and the Home Goals module.
struct GoalsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]
    @Query private var weekSessions: [Session]

    init() {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start
            ?? Calendar.current.startOfDay(for: .now)
        _weekSessions = Query(
            filter: #Predicate<Session> { $0.startDate >= weekStart },
            sort: \Session.startDate
        )
    }

    private var withGoals: [LogCategory] { categories.filter(\.hasGoal) }
    private var withoutGoals: [LogCategory] { categories.filter { !$0.hasGoal } }

    var body: some View {
        NavigationStack {
            Group {
                if categories.isEmpty {
                    ContentUnavailableView(
                        "No categories",
                        systemImage: "tag",
                        description: Text("Add categories in Settings before setting goals.")
                    )
                } else {
                    List {
                        if withGoals.isEmpty {
                            Section {
                                Text("No goals yet. Add one from a category below.")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Section("Goals") {
                                ForEach(withGoals) { category in
                                    NavigationLink {
                                        CategoryEditorView(category: category)
                                    } label: {
                                        GoalRow(category: category, sessions: weekSessions)
                                    }
                                }
                            }
                        }

                        if !withoutGoals.isEmpty {
                            Section("No goal yet") {
                                ForEach(withoutGoals) { category in
                                    NavigationLink {
                                        CategoryEditorView(category: category)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: category.sfSymbol)
                                                .foregroundStyle(.white)
                                                .frame(width: 32, height: 32)
                                                .background(Color(hex: category.colorHex))
                                                .clipShape(Circle())
                                            Text(category.name)
                                            Spacer()
                                            Text("Add goal")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// One goal row: ring + name + a "Target/Limit · Xh · daily" description and progress.
private struct GoalRow: View {
    let category: LogCategory
    let sessions: [Session]

    var body: some View {
        HStack(spacing: 12) {
            if let status = GoalEvaluator.status(for: category, sessions: sessions) {
                GoalRing(
                    status: status,
                    color: Color(hex: category.colorHex),
                    symbol: category.sfSymbol,
                    size: 40,
                    lineWidth: 5
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.callout.weight(.medium))
                    Text(descriptor(status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(goalMinutesString(status.spent)) / \(goalMinutesString(status.target))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(status.direction == .atMost && status.isOver ? .red : .secondary)
            }
        }
    }

    private func descriptor(_ status: GoalStatus) -> String {
        let kind = status.direction == .atLeast ? "Target" : "Limit"
        let period = status.period == .daily ? "daily" : "weekly"
        return "\(kind) · \(goalMinutesString(status.target)) · \(period)"
    }
}

#Preview {
    GoalsView()
        .modelContainer(try! TempoModelContainer.makePreview())
}
