import SwiftUI
import SwiftData
import LifeTrackerCore

struct DayDetailView: View {
    let date: Date

    @Query private var sessions: [Session]

    private let dayStart: Date
    private let dayEnd: Date

    init(date: Date) {
        self.date = date
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.endOfDay(for: date)
        self.dayStart = start
        self.dayEnd = end
        _sessions = Query(
            filter: #Predicate<Session> { $0.startDate >= start && $0.startDate < end },
            sort: \Session.startDate,
            order: .reverse
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DayTimelineBar(sessions: sessions, dayStart: dayStart, dayEnd: dayEnd)
                TodayDonutChart(sessions: sessions, title: "Breakdown")
                CategoryTotals(sessions: sessions)
                SessionList(sessions: sessions)
            }
            .padding()
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }
}
