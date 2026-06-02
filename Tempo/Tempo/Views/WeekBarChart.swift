import SwiftUI
import Charts
import LifeTrackerCore

struct WeekBarChart: View {
    let sessions: [Session]
    var dayCount: Int = 7

    private var bars: [DailyCategoryTotal] {
        SessionAggregates.dailyCategoryTotals(sessions, days: dayCount)
    }

    var body: some View {
        if !bars.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last \(dayCount) days")
                    .font(.headline)
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Day", bar.day, unit: .day),
                        y: .value("Hours", bar.duration / 3600)
                    )
                    .foregroundStyle(Color(hex: bar.category.colorHex))
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text("\(Int(hours))h")
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }
}
