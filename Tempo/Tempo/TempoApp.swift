import SwiftUI
import SwiftData
import UserNotifications
import LifeTrackerCore

@main
struct TempoApp: App {
    let sharedContainer: ModelContainer
    @State private var router: AppRouter
    private let notificationDelegate: NotificationDelegate
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    init() {
        do {
            sharedContainer = try TempoModelContainer.makeShared()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        let router = AppRouter()
        _router = State(initialValue: router)
        notificationDelegate = NotificationDelegate(router: router)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
                .task {
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                    DefaultCategories.seedIfNeeded(in: sharedContainer.mainContext)
                    ConnectivityService.shared.start(container: sharedContainer)
                    await ReflectionNotifications.requestAuthorization()
                    ReflectionNotifications.rescheduleFromDefaults()
                    UntrackedNotifications.rescheduleFromDefaults()
                    WeeklyReviewNotifications.rescheduleFromDefaults()
                }
        }
        .modelContainer(sharedContainer)
    }
}
