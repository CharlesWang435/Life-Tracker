import SwiftUI
import Charts
import LifeTrackerCore

struct WeekBarChart: View {
    let sessions: [Session]
    var dayCount: Int = 7

    private struct DayBar: Identifiable {
        let date: Date
        let category: LogCategory
        let hours: Double
        var id: String { "\(date.timeIntervalSince1970)-\(category.id)" }
    }

    private var bars: [DayBar] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = (0..<dayCount).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.reversed()

        return days.flatMap { day -> [DayBar] in
            let dayEnd = calendar.endOfDay(for: day)
            let daySessions = sessions.filter { $0.startDate >= day && $0.startDate < dayEnd }
            let byCategory = Dictionary(grouping: daySessions, by: { $0.category?.id })
            return byCategory.compactMap { _, items -> DayBar? in
                guard let cat = items.first?.category else { return nil }
                let total = items.reduce(0.0) { $0 + $1.elapsed() }
                guard total > 0 else { return nil }
                return DayBar(date: day, category: cat, hours: total / 3600)
            }
        }
    }

    var body: some View {
        if !bars.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last \(dayCount) days")
                    .font(.headline)
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Day", bar.date, unit: .day),
                        y: .value("Hours", bar.hours)
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
