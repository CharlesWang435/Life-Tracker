import SwiftUI
import Charts
import LifeTrackerCore

struct TodayDonutChart: View {
    let sessions: [Session]
    var title: String = "Breakdown"

    private var slices: [CategoryTotal] { SessionAggregates.categoryTotals(sessions) }

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
