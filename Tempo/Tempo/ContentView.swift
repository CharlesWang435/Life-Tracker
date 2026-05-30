import SwiftUI
import SwiftData
import LifeTrackerCore

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "calendar.day.timeline.left") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            CategoriesView()
                .tabItem { Label("Categories", systemImage: "tag") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(try! TempoModelContainer.makePreview())
}
