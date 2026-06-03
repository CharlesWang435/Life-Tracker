import SwiftUI
import Charts
import LifeTrackerCore

/// One plotted reflection point: a day and its 1–5 rating, rendered as the matching emoji.
struct TrendPoint: Identifiable {
    let date: Date
    let rating: Int
    let emoji: String
    var id: Date { date }
}

/// Emoji-as-datapoint trend chart. Y axis is the 1–5 rating (higher = higher up), X is the
/// date; a faint line connects points so the trend reads at a glance. Empty when no data.
struct MoodTrendChart: View {
    let points: [TrendPoint]
    let tint: Color
    var height: CGFloat = 220

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView(
                "No data in range",
                systemImage: "chart.xyaxis.line",
                description: Text("Reflect on a few days to see your trend.")
            )
            .frame(height: height)
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Rating", point.rating)
                )
                .foregroundStyle(tint.opacity(0.35))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Rating", point.rating)
                )
                .opacity(0)   // hide the dot; the emoji annotation is the marker
                .annotation(position: .overlay) {
                    Text(point.emoji).font(.title3)
                }
            }
            .chartYScale(domain: 0.5...5.5)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let rating = value.as(Int.self) {
                            Text("\(rating)")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: height)
        }
    }
}
