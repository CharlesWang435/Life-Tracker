import SwiftUI
import SwiftData
import LifeTrackerCore

struct HistoryView: View {
    @Query(sort: \Session.startDate, order: .reverse) private var sessions: [Session]

    private var weeks: [WeekGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startDate) }
        let days = byDay
            .map { DayGroup(date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
        let byWeek = Dictionary(grouping: days) { day in
            calendar.dateInterval(of: .weekOfYear, for: day.date)?.start ?? day.date
        }
        return byWeek
            .map { WeekGroup(weekStart: $0.key, days: $0.value) }
            .sorted { $0.weekStart > $1.weekStart }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "clock",
                        description: Text("Start a category to begin logging.")
                    )
                } else {
                    List {
                        ForEach(weeks) { week in
                            Section {
                                ForEach(week.days) { day in
                                    NavigationLink {
                                        DayDetailView(date: day.date)
                                    } label: {
                                        DayRowSummary(date: day.date, sessions: day.sessions)
                                    }
                                }
                            } header: {
                                Text("Week of \(week.weekStart.formatted(date: .abbreviated, time: .omitted))")
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

private struct WeekGroup: Identifiable {
    let weekStart: Date
    let days: [DayGroup]
    var id: Date { weekStart }
}

private struct DayGroup: Identifiable {
    let date: Date
    let sessions: [Session]
    var id: Date { date }
}

private struct DayRowSummary: View {
    let date: Date
    let sessions: [Session]

    private var totalDuration: TimeInterval {
        sessions.reduce(0.0) { $0 + $1.elapsed() }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.callout)
                Text("\(sessions.count) sessions · \(totalDuration.formattedShort)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
