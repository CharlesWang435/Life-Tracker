import SwiftUI
import SwiftData
import LifeTrackerCore

/// The Home tab: a personal dashboard of interactive modules. Each module is a usable
/// mini-version of a feature (start a timer, log a reflection, see a trend) — its header
/// opens the matching tab for the full, in-depth experience. Users add/remove/reorder/
/// resize modules; see `HomeModule` / `EditHomeView`.
struct HomeView: View {
    @Environment(AppRouter.self) private var router

    @Query(filter: #Predicate<Session> { $0.endDate == nil })
    private var activeSessions: [Session]
    @Query(filter: #Predicate<DayEntry> { $0.reflectedAt != nil })
    private var reflectedEntries: [DayEntry]

    @AppStorage(HomeLayout.key) private var layoutRaw = HomeLayout.defaultRaw
    @State private var showingEdit = false
    @State private var showingSettings = false

    private var tiles: [HomeTile] { HomeLayout.parse(layoutRaw) }

    private var reflectedToday: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return reflectedEntries.contains { $0.date == today }
    }

    /// Tiles in display order. Once today's reflection is done, the Reflect tile drops to
    /// the bottom so it's out of the initial view; until then it keeps its placed spot.
    private var displayTiles: [HomeTile] {
        let parsed = tiles
        guard reflectedToday, parsed.contains(where: { $0.module == .reflect }) else { return parsed }
        var result = parsed.filter { $0.module != .reflect }
        if let reflect = parsed.first(where: { $0.module == .reflect }) { result.append(reflect) }
        return result
    }

    /// Pack tiles into rows the way iOS reflows widgets: full-width tiles take their own
    /// row, small tiles pair two-per-row, a trailing lone small keeps its half width.
    private var rows: [[HomeTile]] {
        var result: [[HomeTile]] = []
        var pendingSmall: HomeTile?
        for tile in displayTiles {
            if tile.size.isFullWidth {
                if let p = pendingSmall { result.append([p]); pendingSmall = nil }
                result.append([tile])
            } else if let p = pendingSmall {
                result.append([p, tile]); pendingSmall = nil
            } else {
                pendingSmall = tile
            }
        }
        if let p = pendingSmall { result.append([p]) }
        return result
    }

    private var layoutBinding: Binding<[HomeTile]> {
        Binding(
            get: { HomeLayout.parse(layoutRaw) },
            set: { layoutRaw = HomeLayout.serialize($0) }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if tiles.isEmpty {
                    ContentUnavailableView {
                        Label("Empty dashboard", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Tap Edit to add modules to your Home.")
                    } actions: {
                        Button("Edit Home") { showingEdit = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 20) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(row) { tile in
                                    moduleCard(tile)
                                }
                                if row.count == 1, !row[0].size.isFullWidth {
                                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                                }
                            }
                        }
                    }
                    .padding()
                    .animation(.smooth, value: reflectedToday)
                }
            }
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingEdit = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Edit Home")
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
            .sheet(isPresented: $showingEdit) {
                EditHomeView(tiles: layoutBinding)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: Module rendering — each module is an interactive mini-feature.

    @ViewBuilder
    private func moduleCard(_ tile: HomeTile) -> some View {
        switch tile.module {
        case .activeTimer:
            ActiveTimerBanner(activeSession: activeSessions.first)
        case .reflect:
            ReflectionCard()
        case .categories:
            QuickStartModule(size: tile.size)
        case .todaySnapshot:
            TodaySummaryModule(size: tile.size)
        case .moodTrend:
            MoodTrendModule(size: tile.size)
        case .history:
            RecentHistoryModule(size: tile.size)
        case .goals:
            GoalsModule(size: tile.size)
        case .streaks:
            StreaksModule(size: tile.size)
        case .insights:
            InsightsModule(size: tile.size)
        case .heatmap:
            HeatmapModule(size: tile.size)
        case .intentions:
            IntentionsModule(size: tile.size)
        case .weeklyReview:
            WeeklyReviewModule(size: tile.size)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
        .modelContainer(try! TempoModelContainer.makePreview())
}
