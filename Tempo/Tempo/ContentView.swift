import SwiftUI
import SwiftData
import LifeTrackerCore

struct ContentView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    /// Start-of-day the day-scoped screens are keyed to. Bumping it recreates them (and
    /// their date-baked `@Query` predicates) so "today" stays correct across midnight.
    @State private var dayBucket = Calendar.current.startOfDay(for: .now)

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tag(AppTab.home)
                .tabItem { Label("Home", systemImage: "square.grid.2x2") }
            TodayView()
                .tag(AppTab.today)
                .tabItem { Label("Today", systemImage: "calendar.day.timeline.left") }
            ReflectView()
                .tag(AppTab.reflect)
                .tabItem { Label("Reflect", systemImage: "moon.stars") }
            HistoryView()
                .tag(AppTab.history)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .id(dayBucket)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDay() }
        }
        .task { await watchForMidnight() }
        // One sheet for all notification deep links — a single value can't get stuck.
        .sheet(item: $router.deepLink) { link in
            switch link {
            case .reflection: NavigationStack { ReflectionView(date: .now) }
            case .dayReview: DayReviewView()
            case .weeklyReview: WeeklyReviewView()
            }
        }
    }

    private func refreshDay() {
        let today = Calendar.current.startOfDay(for: .now)
        if today != dayBucket { dayBucket = today }
    }

    /// While the app stays foregrounded, roll the day over at midnight too (scenePhase
    /// handles the backgrounded-then-reopened case).
    private func watchForMidnight() async {
        while !Task.isCancelled {
            let now = Date()
            let nextMidnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
            let seconds = max(60, nextMidnight.timeIntervalSince(now))
            try? await Task.sleep(for: .seconds(seconds))
            refreshDay()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
        .modelContainer(try! TempoModelContainer.makePreview())
}
