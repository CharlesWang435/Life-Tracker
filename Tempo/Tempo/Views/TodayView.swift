import SwiftUI
import SwiftData
import LifeTrackerCore

struct TodayView: View {
    @Query private var allCategories: [LogCategory]
    @Query(sort: \Session.startDate, order: .reverse) private var allSessions: [Session]

    @AppStorage("today.sort") private var sortRaw: String = CategorySort.custom.rawValue
    @AppStorage("today.viewStyle") private var styleRaw: String = CategoryViewStyle.grid.rawValue

    @State private var showingManualEntry = false

    private var sort: CategorySort {
        get { CategorySort(rawValue: sortRaw) ?? .custom }
    }
    private var viewStyle: CategoryViewStyle {
        get { CategoryViewStyle(rawValue: styleRaw) ?? .grid }
    }

    private var dayStart: Date { Calendar.current.startOfDay(for: .now) }
    private var dayEnd: Date { Calendar.current.date(byAdding: .day, value: 1, to: dayStart)! }

    private var sortedCategories: [LogCategory] {
        sort.apply(to: allCategories)
    }

    private var todaySessions: [Session] {
        allSessions.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ActiveTimerBanner()
                    CategoryPicker(
                        categories: sortedCategories,
                        style: viewStyle,
                        todaySessions: todaySessions
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
