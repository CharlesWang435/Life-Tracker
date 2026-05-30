import SwiftUI
import SwiftData
import LifeTrackerCore

struct DayDetailView: View {
    let date: Date
    @Query(sort: \Session.startDate, order: .reverse) private var allSessions: [Session]

    private var dayStart: Date { Calendar.current.startOfDay(for: date) }
    private var dayEnd: Date { Calendar.current.date(byAdding: .day, value: 1, to: dayStart)! }

    private var sessions: [Session] {
        allSessions.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DayTimelineBar(sessions: sessions, dayStart: dayStart, dayEnd: dayEnd)
                CategoryTotals(sessions: sessions)
                SessionList(sessions: sessions)
            }
            .padding()
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }
}
