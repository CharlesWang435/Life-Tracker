import Foundation

/// A module's size on the dashboard, à la iOS widgets.
/// `small` = half-width tile; `medium` = full-width short; `large` = full-width tall.
enum HomeModuleSize: String, CaseIterable, Codable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var systemImage: String {
        switch self {
        case .small: return "square"
        case .medium: return "rectangle"
        case .large: return "rectangle.portrait"
        }
    }

    /// Small tiles pack two-per-row; medium/large span the full width.
    var isFullWidth: Bool { self != .small }

    /// Fixed card height so every module of the same size renders identically (iOS-widget
    /// model: small and medium share a height; large is roughly double + the row gap).
    /// Width is decided by the row-packing layout.
    var height: CGFloat {
        switch self {
        case .small, .medium: return 180
        case .large: return 376   // 2 × 180 + 16pt row spacing
        }
    }
}

/// Every dashboard module the user can add/remove/reorder/resize. Adding a future feature
/// to Home is: add a case here + a render case in `HomeView` — that's the whole story.
enum HomeModule: String, CaseIterable, Identifiable, Codable {
    case activeTimer
    case reflect
    case todaySnapshot
    case moodTrend
    case history
    case categories
    case goals
    case streaks
    case insights
    case heatmap
    case intentions
    case weeklyReview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activeTimer: return "Active timer"
        case .reflect: return "Reflect"
        case .todaySnapshot: return "Today"
        case .moodTrend: return "Mood"
        case .history: return "Recent"
        case .categories: return "Categories"
        case .goals: return "Goals"
        case .streaks: return "Streaks"
        case .insights: return "Insights"
        case .heatmap: return "Activity"
        case .intentions: return "Plan"
        case .weeklyReview: return "Weekly review"
        }
    }

    var systemImage: String {
        switch self {
        case .activeTimer: return "timer"
        case .reflect: return "moon.stars"
        case .todaySnapshot: return "calendar.day.timeline.left"
        case .moodTrend: return "chart.xyaxis.line"
        case .history: return "clock.arrow.circlepath"
        case .categories: return "square.grid.2x2"
        case .goals: return "target"
        case .streaks: return "flame.fill"
        case .insights: return "lightbulb"
        case .heatmap: return "square.grid.3x3.fill"
        case .intentions: return "checklist"
        case .weeklyReview: return "calendar.badge.clock"
        }
    }

    /// Sizes a module supports. The interactive banners are full-width only; the feature
    /// tiles support the full S/M/L range. A single-element list hides the resize control.
    var allowedSizes: [HomeModuleSize] {
        switch self {
        case .activeTimer, .reflect: return [.medium]
        case .todaySnapshot, .moodTrend, .history, .categories, .goals, .streaks, .insights, .heatmap, .intentions, .weeklyReview: return [.small, .medium, .large]
        }
    }

    var defaultSize: HomeModuleSize {
        allowedSizes.contains(.small) ? .small : .medium
    }

    /// What's enabled, in order, for a fresh install.
    static var defaultLayout: [HomeModule] {
        // A focused first-run dashboard; every other module stays available via Edit → Add.
        [.activeTimer, .categories, .reflect, .intentions, .todaySnapshot, .goals, .streaks]
    }
}

/// A placed module: which module, at what size. The unit the dashboard lays out.
struct HomeTile: Identifiable, Equatable {
    let module: HomeModule
    var size: HomeModuleSize
    var id: String { module.rawValue }
}

/// Reads/writes the user's Home layout (ordered `module:size` pairs) as a CSV in
/// UserDefaults. Unknown ids and out-of-range sizes are corrected, so the format
/// survives adding/removing module cases or changing a module's allowed sizes.
enum HomeLayout {
    static let key = "home.layout.v1"

    static func parse(_ raw: String) -> [HomeTile] {
        raw.split(separator: ",").compactMap { token -> HomeTile? in
            let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
            guard let module = HomeModule(rawValue: parts[0]) else { return nil }
            let parsedSize = parts.count > 1 ? HomeModuleSize(rawValue: parts[1]) : nil
            var size = parsedSize ?? module.defaultSize
            if !module.allowedSizes.contains(size) { size = module.defaultSize }
            return HomeTile(module: module, size: size)
        }
    }

    static func serialize(_ tiles: [HomeTile]) -> String {
        tiles.map { "\($0.module.rawValue):\($0.size.rawValue)" }.joined(separator: ",")
    }

    static var defaultTiles: [HomeTile] {
        HomeModule.defaultLayout.map { HomeTile(module: $0, size: $0.defaultSize) }
    }

    static var defaultRaw: String { serialize(defaultTiles) }
}
