import SwiftUI
import SwiftData
import LifeTrackerCore

/// A GitHub-style contribution grid: one small square per day, shaded by how much time was
/// tracked. Columns are weeks, rows are weekdays. Scrolls horizontally if it overflows.
struct HeatmapView: View {
    let grid: [[HeatmapDay]]
    var tint: Color = .green
    var cell: CGFloat = 13
    var spacing: CGFloat = 3

    private var maxSeconds: TimeInterval { Heatmap.maxSeconds(grid) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: spacing) {
                        ForEach(week) { day in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color(for: day))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func color(for day: HeatmapDay) -> Color {
        if day.isFuture { return .clear }
        guard maxSeconds > 0, day.seconds > 0 else { return Color(.tertiarySystemFill) }
        // Four intensity buckets.
        let ratio = day.seconds / maxSeconds
        let opacity: Double
        switch ratio {
        case ..<0.25: opacity = 0.30
        case ..<0.50: opacity = 0.50
        case ..<0.75: opacity = 0.75
        default: opacity = 1.0
        }
        return tint.opacity(opacity)
    }
}

// MARK: - Home module

struct HeatmapModule: View {
    let size: HomeModuleSize

    @Environment(AppRouter.self) private var router
    @Query(sort: \Session.startDate) private var sessions: [Session]

    private var weeks: Int {
        switch size {
        case .small: return 8
        case .medium: return 16
        case .large: return 26
        }
    }

    var body: some View {
        ModuleCard(title: "Activity", systemImage: "square.grid.3x3.fill", tint: .green,
                   height: size.height, onOpen: { router.selectedTab = .history }) {
            let grid = Heatmap.grid(sessions: sessions, weeks: weeks)
            if Heatmap.maxSeconds(grid) == 0 {
                Text("Your tracked days will fill in here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HeatmapView(grid: grid, cell: size == .small ? 11 : 13)
            }
        }
    }
}
