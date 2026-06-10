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

    private var total: TimeInterval { SessionAggregates.grandTotal(sessions) }
    private var hasContent: Bool { !sessions.isEmpty }

    /// A shareable summary of the day: total, highlight, mood, and top categories.
    private var shareModel: SummaryShareModel {
        let totals = SessionAggregates.categoryTotals(sessions)
        let rows = totals.prefix(3).map { item in
            SummaryShareModel.Row(
                name: item.category.name,
                colorHex: item.category.colorHex,
                fraction: total > 0 ? item.duration / total : 0,
                valueString: item.duration.formattedShort
            )
        }
        return SummaryShareModel(
            title: date.formatted(.dateTime.weekday(.wide).month().day()),
            totalString: total.formattedShort,
            subtitle: entry?.highlight,
            rows: rows,
            accentEmoji: entry?.moodRating.flatMap { ReflectionAxis.mood.emoji(for: $0) }
        )
    }

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
            if hasContent {
                ToolbarItem(placement: .topBarTrailing) {
                    SummaryShareLink(model: shareModel)
                }
            }
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
