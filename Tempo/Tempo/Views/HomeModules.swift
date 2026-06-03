import SwiftUI
import SwiftData
import LifeTrackerCore

/// Shared container for interactive Home modules: a tappable header (icon + title +
/// chevron) that opens the full tab, over a body whose own controls stay independently
/// interactive (the header is a separate button, so chips / links inside the body work).
struct ModuleCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    /// Fixed card height (from `HomeModuleSize.height`) so all same-size modules match.
    let height: CGFloat
    var onOpen: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                onOpen?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if onOpen != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(onOpen == nil)

            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Quick Start (interactive: tap a category to start/stop a timer)

struct QuickStartModule: View {
    let size: HomeModuleSize

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]
    @Query(filter: #Predicate<Session> { $0.endDate == nil }) private var active: [Session]

    private var activeID: UUID? { active.first?.category?.id }

    /// Favourites first (most-tapped), then manual order. Count scales with size.
    private var shown: [LogCategory] {
        let sorted = categories.sorted {
            $0.tapCount != $1.tapCount ? $0.tapCount > $1.tapCount : $0.sortOrder < $1.sortOrder
        }
        let limit: Int
        switch size {
        case .small: limit = 4
        case .medium: limit = 8
        case .large: limit = categories.count
        }
        return Array(sorted.prefix(limit))
    }

    var body: some View {
        ModuleCard(title: "Categories", systemImage: "square.grid.2x2", tint: .pink,
                   height: size.height, onOpen: { router.selectedTab = .today }) {
            if categories.isEmpty {
                Text("Add categories in Settings to start.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                CompactCategoryGrid(categories: shown, activeID: activeID, onTap: handleTap)
                    .sensoryFeedback(.impact(weight: .medium), trigger: activeID)
            }
        }
    }

    private func handleTap(_ category: LogCategory) {
        if activeID == category.id {
            SessionActions.stopActive(in: context)
        } else {
            SessionActions.start(category: category, in: context)
        }
    }
}

// MARK: - Today summary (live timeline + totals; opens Today for depth)

struct TodaySummaryModule: View {
    let size: HomeModuleSize

    @Environment(AppRouter.self) private var router
    @Query private var todaySessions: [Session]

    init(size: HomeModuleSize) {
        self.size = size
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.endOfDay(for: .now)
        _todaySessions = Query(
            filter: #Predicate<Session> { $0.startDate >= start && $0.startDate < end },
            sort: \Session.startDate, order: .reverse
        )
    }

    private var trackedToday: TimeInterval { SessionAggregates.grandTotal(todaySessions) }

    var body: some View {
        ModuleCard(title: "Today", systemImage: "calendar.day.timeline.left", tint: .blue,
                   height: size.height, onOpen: { router.selectedTab = .today }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(trackedToday > 0 ? trackedToday.formattedShort + " tracked" : "Nothing yet")
                    .font(.title3.weight(.semibold))
                if size == .large {
                    DayTimelineBar(sessions: todaySessions,
                                   dayStart: Calendar.current.startOfDay(for: .now),
                                   dayEnd: Calendar.current.endOfDay(for: .now))
                } else {
                    MiniProportionBar(sessions: todaySessions)
                }
            }
        }
    }
}

// MARK: - Mood trend (chart in place; opens Reflect for depth)

struct MoodTrendModule: View {
    let size: HomeModuleSize

    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<DayEntry> { $0.reflectedAt != nil },
           sort: \DayEntry.date, order: .reverse)
    private var reflections: [DayEntry]

    /// Recent mood points (oldest first) for the in-place chart.
    private var points: [TrendPoint] {
        reflections
            .prefix(size == .large ? 30 : 14)
            .compactMap { entry -> TrendPoint? in
                guard let mood = entry.moodRating, let emoji = ReflectionAxis.mood.emoji(for: mood) else { return nil }
                return TrendPoint(date: entry.date, rating: mood, emoji: emoji)
            }
            .sorted { $0.date < $1.date }
    }

    private var recentEmojis: [String] {
        reflections.prefix(7).compactMap { $0.moodRating.flatMap(ReflectionAxis.mood.emoji(for:)) }.reversed()
    }

    var body: some View {
        ModuleCard(title: "Mood", systemImage: "chart.xyaxis.line", tint: .indigo,
                   height: size.height, onOpen: { router.selectedTab = .reflect }) {
            if size == .small {
                if recentEmojis.isEmpty {
                    Text("Reflect to see your trend")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(recentEmojis.joined(separator: " "))
                        .font(.title3).lineLimit(1)
                }
            } else {
                // Fit the chart within the fixed card height (minus header + padding).
                MoodTrendChart(points: points, tint: .indigo, height: size.height - 72)
            }
        }
    }
}

// MARK: - Recent history (last few days; tap a day → detail)

struct RecentHistoryModule: View {
    let size: HomeModuleSize

    @Environment(AppRouter.self) private var router
    @Query(sort: \Session.startDate, order: .reverse) private var sessions: [Session]

    private struct DayGroup: Identifiable {
        let date: Date
        let sessions: [Session]
        var id: Date { date }
    }

    private var recentDays: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startDate) }
        let days = grouped.map { DayGroup(date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
        let limit: Int = size == .small ? 2 : (size == .medium ? 3 : 6)
        return Array(days.prefix(limit))
    }

    var body: some View {
        ModuleCard(title: "Recent", systemImage: "clock.arrow.circlepath", tint: .teal,
                   height: size.height, onOpen: { router.selectedTab = .history }) {
            if recentDays.isEmpty {
                Text("No history yet")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(recentDays) { day in
                        NavigationLink {
                            DayDetailView(date: day.date)
                        } label: {
                            HStack {
                                Text(day.date.formatted(.dateTime.weekday(.abbreviated).month().day()))
                                    .font(.caption)
                                Spacer()
                                Text("\(day.sessions.count)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Goals (progress rings for categories with a goal)

struct GoalsModule: View {
    let size: HomeModuleSize

    @Query(filter: #Predicate<LogCategory> { $0.goalMinutes != nil },
           sort: \LogCategory.sortOrder)
    private var goalCategories: [LogCategory]
    @Query private var sessions: [Session]
    @State private var showingGoals = false

    init(size: HomeModuleSize) {
        self.size = size
        // Pull this week's sessions so weekly goals are correct; daily goals filter within.
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start
            ?? Calendar.current.startOfDay(for: .now)
        _sessions = Query(
            filter: #Predicate<Session> { $0.startDate >= weekStart },
            sort: \Session.startDate
        )
    }

    var body: some View {
        ModuleCard(title: "Goals", systemImage: "target", tint: .green,
                   height: size.height, onOpen: { showingGoals = true }) {
            if goalCategories.isEmpty {
                Text("Set a goal on a category in Settings → Manage Categories.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                GoalRingsView(
                    categories: goalCategories,
                    sessions: sessions,
                    ringSize: size == .small ? 44 : 56
                )
            }
        }
        .sheet(isPresented: $showingGoals) { GoalsView() }
    }
}

// MARK: - Plan (morning intention)

struct IntentionsModule: View {
    let size: HomeModuleSize

    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]
    @Query private var todayEntries: [DayEntry]
    @Query private var todaySessions: [Session]
    @State private var showingPlan = false

    init(size: HomeModuleSize) {
        self.size = size
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.endOfDay(for: .now)
        _todayEntries = Query(filter: #Predicate<DayEntry> { $0.date == start })
        _todaySessions = Query(filter: #Predicate<Session> { $0.startDate >= start && $0.startDate < end })
    }

    private var intendedIDs: [UUID] { todayEntries.first?.intendedCategoryIDs ?? [] }
    private var doneCount: Int {
        IntentionEvaluator.completedCount(intendedIDs: intendedIDs, sessions: todaySessions)
    }

    var body: some View {
        ModuleCard(title: "Plan", systemImage: "checklist", tint: .mint,
                   height: size.height, onOpen: { showingPlan = true }) {
            if intendedIDs.isEmpty {
                Text("Plan the categories you want to focus on today.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(doneCount) of \(intendedIDs.count) done")
                        .font(.subheadline.weight(.medium))
                    IntentionChips(categories: categories, intendedIDs: intendedIDs,
                                   sessions: todaySessions, compact: size == .small)
                }
            }
        }
        .sheet(isPresented: $showingPlan) { PlanTodayView(date: .now) }
    }
}

// MARK: - Weekly review (opens the recap)

struct WeeklyReviewModule: View {
    let size: HomeModuleSize

    @Query private var weekSessions: [Session]
    @State private var showingReview = false

    init(size: HomeModuleSize) {
        self.size = size
        let weekStart = Calendar.current.date(
            byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)
        ) ?? .now
        _weekSessions = Query(filter: #Predicate<Session> { $0.startDate >= weekStart })
    }

    private var total: TimeInterval { SessionAggregates.grandTotal(weekSessions) }

    var body: some View {
        ModuleCard(title: "Weekly review", systemImage: "calendar.badge.clock", tint: .purple,
                   height: size.height, onOpen: { showingReview = true }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(total > 0 ? total.formattedShort : "—")
                    .font(.title3.weight(.semibold))
                Text("tracked in the last 7 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingReview) { WeeklyReviewView() }
    }
}

// MARK: - Streaks (consecutive-day momentum)

struct StreaksModule: View {
    let size: HomeModuleSize

    @Environment(AppRouter.self) private var router
    @Query(sort: \Session.startDate) private var sessions: [Session]
    @Query(filter: #Predicate<DayEntry> { $0.reflectedAt != nil }) private var reflections: [DayEntry]

    private var loggingStreak: Int {
        Streak.current(days: Streak.loggedDays(from: sessions))
    }
    private var reflectionStreak: Int {
        Streak.current(days: reflections.map(\.date))
    }

    var body: some View {
        ModuleCard(title: "Streaks", systemImage: "flame.fill", tint: .orange,
                   height: size.height, onOpen: { router.selectedTab = .reflect }) {
            VStack(alignment: .leading, spacing: 12) {
                StreakRow(icon: "flame.fill", tint: .orange,
                          count: loggingStreak, noun: "day", label: "logged")
                StreakRow(icon: "moon.stars.fill", tint: .indigo,
                          count: reflectionStreak, noun: "day", label: "reflected")
            }
        }
    }
}

/// One streak line: a colored count + gentle phrasing ("5-day logging streak" / "Start one today").
private struct StreakRow: View {
    let icon: String
    let tint: Color
    let count: Int
    let noun: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(count > 0 ? tint : .secondary)
                .frame(width: 24)
            if count > 0 {
                Text("\(count)")
                    .font(.title3.weight(.bold).monospacedDigit())
                Text("\(noun)\(count == 1 ? "" : "s") \(label)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start a \(label) streak today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Insights (auto-generated stat cards)

struct InsightsModule: View {
    let size: HomeModuleSize

    @Query(sort: \Session.startDate, order: .reverse) private var sessions: [Session]
    @Query(filter: #Predicate<DayEntry> { $0.reflectedAt != nil }) private var reflections: [DayEntry]

    private var insights: [Insight] {
        let all = InsightEngine.insights(sessions: sessions, dayEntries: reflections)
        let limit = size == .small ? 1 : (size == .medium ? 2 : 4)
        return Array(all.prefix(limit))
    }

    var body: some View {
        ModuleCard(title: "Insights", systemImage: "lightbulb", tint: .yellow, height: size.height) {
            if insights.isEmpty {
                Text("Log a few sessions to surface insights.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(insights) { insight in
                        InsightRow(insight: insight)
                    }
                }
            }
        }
    }
}

private struct InsightRow: View {
    let insight: Insight

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: insight.systemImage)
                .font(.callout)
                .foregroundStyle(insight.colorHex.map { Color(hex: $0) } ?? .yellow)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(insight.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Shared bits

/// A slim color-proportion bar of today's category time — a compact stand-in for the
/// full timeline. Shows a placeholder when empty.
struct MiniProportionBar: View {
    let sessions: [Session]

    var body: some View {
        let totals = SessionAggregates.categoryTotals(sessions)
        let sum = totals.reduce(0.0) { $0 + $1.duration }
        GeometryReader { geo in
            if sum > 0 {
                HStack(spacing: 1) {
                    ForEach(totals) { total in
                        Rectangle()
                            .fill(Color(hex: total.category.colorHex))
                            .frame(width: max(2, geo.size.width * (total.duration / sum)))
                    }
                }
            } else {
                Capsule().fill(Color(.tertiarySystemFill))
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }
}
