import SwiftUI
import SwiftData
import LifeTrackerCore

struct TodayView: View {
    @Query private var allCategories: [LogCategory]
    @Query private var todaySessions: [Session]
    /// This week's sessions, used so weekly goals show correct progress in the rings.
    @Query private var weekSessions: [Session]
    /// All sessions — history for ranking gap-fill suggestions by time of day.
    @Query(sort: \Session.startDate) private var allSessions: [Session]
    @Query(filter: #Predicate<Session> { $0.endDate == nil })
    private var activeSessions: [Session]
    /// Today's reflection entry (if any), to decide whether to surface the reflect card on top.
    @Query private var todayEntries: [DayEntry]

    @AppStorage("today.sort") private var sortRaw: String = CategorySort.custom.rawValue
    @AppStorage("today.viewStyle") private var styleRaw: String = CategoryViewStyle.grid.rawValue
    @AppStorage(ReflectionNotifications.Defaults.hour) private var reflectionHour = 20
    @AppStorage(ReflectionNotifications.Defaults.minute) private var reflectionMinute = 0

    @State private var showingManualEntry = false
    @State private var showingSettings = false
    @State private var showingGoals = false
    @State private var showingManageCategories = false
    @State private var showingPlan = false
    @State private var dismissedGapStart: Date?
    @State private var dismissedNudgeID: UUID?
    @State private var showingDayReview = false

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
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? start
        _weekSessions = Query(
            filter: #Predicate<Session> { $0.startDate >= weekStart },
            sort: \Session.startDate
        )
        _todayEntries = Query(filter: #Predicate<DayEntry> { $0.date == start })
    }

    private var isReflectedToday: Bool { todayEntries.first?.isReflected ?? false }
    private var intendedIDs: [UUID] { todayEntries.first?.intendedCategoryIDs ?? [] }

    /// The reflect prompt only appears once it's past the user's reflection time — no point
    /// asking how the day went when it's just begun.
    private var isPastReflectionTime: Bool {
        let now = Date()
        guard let time = Calendar.current.date(
            bySettingHour: reflectionHour, minute: reflectionMinute, second: 0, of: now
        ) else { return true }
        return now >= time
    }

    /// Untracked gap to offer backfilling (unless the user dismissed this one).
    private var gap: UntrackedGap? {
        guard let g = CaptureQuality.currentGap(sessions: todaySessions) else { return nil }
        return g.start == dismissedGapStart ? nil : g
    }

    /// Every untracked hole in today's timeline (for the whole-day review).
    private var dayGaps: [UntrackedGap] { CaptureQuality.allGaps(sessions: todaySessions) }

    /// Which conditional cards are currently shown — changing this animates them in/out.
    private var cardSignature: [Bool] {
        [longRunning != nil,
         gap != nil,
         !isReflectedToday && isPastReflectionTime,
         isReflectedToday,
         !dayGaps.isEmpty,
         GoalRingsView.hasGoals(in: allCategories)]
    }

    /// Active session + elapsed when it's run long enough to nudge (unless dismissed).
    private var longRunning: (session: Session, elapsed: TimeInterval)? {
        guard let active = activeSessions.first,
              let elapsed = CaptureQuality.longRunning(activeSession: active),
              active.id != dismissedNudgeID else { return nil }
        return (active, elapsed)
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
                    if let lr = longRunning {
                        LongRunningNudge(session: lr.session, elapsed: lr.elapsed,
                                         onDismiss: { dismissedNudgeID = lr.session.id })
                            .transition(.opacity)
                    }
                    if let gap {
                        GapBackfillCard(
                            gap: gap,
                            categories: GapSuggester.ranked(categories: sortedCategories, history: allSessions, gap: gap),
                            onDismiss: { dismissedGapStart = gap.start }
                        )
                        .transition(.opacity)
                    }
                    if !isReflectedToday && isPastReflectionTime {
                        ReflectionCard()
                            .transition(.opacity)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Today's plan")
                                .font(.headline)
                            Spacer()
                            Button(intendedIDs.isEmpty ? "Plan" : "Edit") { showingPlan = true }
                                .font(.subheadline)
                        }
                        if intendedIDs.isEmpty {
                            Button { showingPlan = true } label: {
                                Text("Pick a few categories to focus on today.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            IntentionChips(categories: allCategories, intendedIDs: intendedIDs, sessions: todaySessions)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    SuggestionBanner(
                        categories: sortedCategories,
                        activeCategoryID: activeSessions.first?.category?.id
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Categories")
                                .font(.headline)
                            Spacer()
                            Button("Edit") { showingManageCategories = true }
                                .font(.subheadline)
                        }
                        CategoryPicker(
                            categories: sortedCategories,
                            style: viewStyle,
                            todaySessions: todaySessions,
                            activeID: activeSessions.first?.category?.id
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if GoalRingsView.hasGoals(in: allCategories) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Goals")
                                    .font(.headline)
                                Spacer()
                                Button("Edit") { showingGoals = true }
                                    .font(.subheadline)
                            }
                            GoalRingsView(categories: sortedCategories, sessions: weekSessions)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    DayTimelineBar(sessions: todaySessions, dayStart: dayStart, dayEnd: dayEnd)
                    if !dayGaps.isEmpty {
                        Button {
                            showingDayReview = true
                        } label: {
                            Label("Review untracked time (\(dayGaps.count))", systemImage: "calendar.badge.exclamationmark")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .tint(.orange)
                        .transition(.opacity)
                    }
                    TodayDonutChart(sessions: todaySessions, title: "Today's breakdown")
                    CategoryTotals(sessions: todaySessions)
                    SessionList(sessions: todaySessions)
                    // Once reflected, the card lives at the bottom — done, but still editable.
                    if isReflectedToday {
                        ReflectionCard()
                            .transition(.opacity)
                    }
                }
                .padding()
                .animation(.smooth, value: cardSignature)
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
                    .accessibilityLabel("Add a past session")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                NavigationStack {
                    ManualSessionEditor(session: nil)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingGoals) {
                GoalsView()
            }
            .sheet(isPresented: $showingPlan) {
                PlanTodayView(date: .now)
            }
            .sheet(isPresented: $showingDayReview) {
                DayReviewView()
            }
            .sheet(isPresented: $showingManageCategories) {
                NavigationStack {
                    CategoriesView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") { showingManageCategories = false }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(try! TempoModelContainer.makePreview())
}
