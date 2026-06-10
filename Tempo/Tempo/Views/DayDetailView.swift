import SwiftUI
import SwiftData
import LifeTrackerCore

struct DayDetailView: View {
    let date: Date

    @Query private var sessions: [Session]
    @Query private var dayEntries: [DayEntry]

    @State private var showReflection = false

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
        _dayEntries = Query(filter: #Predicate<DayEntry> { $0.date == start })
    }

    private var entry: DayEntry? { dayEntries.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let entry {
                    ReflectionSummaryCard(entry: entry)
                }
                DayTimelineBar(sessions: sessions, dayStart: dayStart, dayEnd: dayEnd)
                TodayDonutChart(sessions: sessions, title: "Breakdown")
                CategoryTotals(sessions: sessions)
                SessionList(sessions: sessions)
            }
            .padding()
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(entry?.isReflected == true ? "Edit" : "Reflect") {
                    showReflection = true
                }
            }
        }
        .sheet(isPresented: $showReflection) {
            NavigationStack { ReflectionView(date: date) }
        }
    }
}
