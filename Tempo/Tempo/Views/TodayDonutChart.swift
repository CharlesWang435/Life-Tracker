import SwiftUI
import Charts
import LifeTrackerCore

struct TodayDonutChart: View {
    let sessions: [Session]
    var title: String = "Breakdown"

    private struct Slice: Identifiable {
        let category: LogCategory
        let duration: TimeInterval
        var id: UUID { category.id }
    }

    private var slices: [Slice] {
        let groups = Dictionary(grouping: sessions, by: { $0.category?.id })
        return groups.compactMap { _, items -> Slice? in
            guard let category = items.first?.category else { return nil }
            let total = items.reduce(0.0) { $0 + $1.elapsed() }
            guard total > 0 else { return nil }
            return Slice(category: category, duration: total)
        }
        .sorted { $0.duration > $1.duration }
    }

    private var total: TimeInterval { slices.reduce(0.0) { $0 + $1.duration } }

    var body: some View {
        if !slices.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                ZStack {
                    Chart(slices) { slice in
                        SectorMark(
                            angle: .value("Time", slice.duration),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .cornerRadius(4)
                        .foregroundStyle(Color(hex: slice.category.colorHex))
                    }
                    .frame(height: 190)

                    VStack(spacing: 2) {
                        Text(total.formattedShort)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                        Text("tracked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
