import SwiftUI
import SwiftData
import LifeTrackerCore

struct HistoryView: View {
    @Query(sort: \Session.startDate, order: .reverse) private var sessions: [Session]
    @Query(sort: \LogCategory.sortOrder) private var allCategories: [LogCategory]

    @State private var searchText: String = ""
    @State private var filterCategoryID: UUID? = nil

    private var filteredSessions: [Session] {
        sessions.filter { session in
            if let id = filterCategoryID, session.category?.id != id { return false }
            if searchText.isEmpty { return true }
            return session.category?.name.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    private var weeks: [WeekGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: filteredSessions) { calendar.startOfDay(for: $0.startDate) }
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

    private var hasAnyHistory: Bool { !sessions.isEmpty }
    private var hasMatches: Bool { !filteredSessions.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if !hasAnyHistory {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "clock",
                        description: Text("Start a category to begin logging.")
                    )
                } else if !hasMatches {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        Section {
                            WeekBarChart(sessions: filteredSessions)
                                .padding(.vertical, 8)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
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
            .searchable(text: $searchText, prompt: "Search by category")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            filterCategoryID = nil
                        } label: {
                            Label("All categories", systemImage: filterCategoryID == nil ? "checkmark" : "")
                        }
                        Divider()
                        ForEach(allCategories) { cat in
                            Button {
                                filterCategoryID = (filterCategoryID == cat.id) ? nil : cat.id
                            } label: {
                                Label(cat.name, systemImage: filterCategoryID == cat.id ? "checkmark" : cat.sfSymbol)
                            }
                        }
                    } label: {
                        Image(systemName: filterCategoryID == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
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
