import SwiftUI
import SwiftData
import LifeTrackerCore

struct TodayView: View {
    @Query private var allCategories: [LogCategory]
    @Query private var todaySessions: [Session]
    @Query(filter: #Predicate<Session> { $0.endDate == nil })
    private var activeSessions: [Session]

    @AppStorage("today.sort") private var sortRaw: String = CategorySort.custom.rawValue
    @AppStorage("today.viewStyle") private var styleRaw: String = CategoryViewStyle.grid.rawValue

    @State private var showingManualEntry = false

    private let dayStart: Date
    private let dayEnd: Date

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.endOfDay(for: .now)
        self.dayStart = start
        self.dayEnd = end
        _todaySessions = Query(
            filter: #Predicate<Session> { $0.startDate >= start && $0.startDate < end },
            sort: \Session.startDate,
            order: .reverse
        )
    }

    private var sort: CategorySort { CategorySort(rawValue: sortRaw) ?? .custom }
    private var viewStyle: CategoryViewStyle { CategoryViewStyle(rawValue: styleRaw) ?? .grid }

    private var sortedCategories: [LogCategory] {
        sort.apply(to: allCategories)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ActiveTimerBanner(activeSession: activeSessions.first)
                    SuggestionBanner(
                        categories: sortedCategories,
                        activeCategoryID: activeSessions.first?.category?.id
                    )
                    CategoryPicker(
                        categories: sortedCategories,
                        style: viewStyle,
                        todaySessions: todaySessions,
                        activeID: activeSessions.first?.category?.id
                    )
                    DayTimelineBar(sessions: todaySessions, dayStart: dayStart, dayEnd: dayEnd)
                    TodayDonutChart(sessions: todaySessions, title: "Today's breakdown")
                    CategoryTotals(sessions: todaySessions)
                    SessionList(sessions: todaySessions)
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sortRaw) {
                            ForEach(CategorySort.allCases) { option in
                                Label(option.label, systemImage: option.systemImage)
                                    .tag(option.rawValue)
                            }
                        }
                        Picker("View", selection: $styleRaw) {
                            ForEach(CategoryViewStyle.allCases) { option in
                                Label(option.label, systemImage: option.systemImage)
                                    .tag(option.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingManualEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                NavigationStack {
                    ManualSessionEditor(session: nil)
                }
            }
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(try! TempoModelContainer.makePreview())
}
