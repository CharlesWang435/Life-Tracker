import SwiftUI
import LifeTrackerCore

enum CategorySort: String, CaseIterable, Identifiable {
    case custom, mostUsed, alphabetical
    var id: String { rawValue }

    var label: String {
        switch self {
        case .custom: "Custom order"
        case .mostUsed: "Most used"
        case .alphabetical: "Alphabetical"
        }
    }

    var systemImage: String {
        switch self {
        case .custom: "hand.draw"
        case .mostUsed: "chart.bar.fill"
        case .alphabetical: "textformat"
        }
    }

    func apply(to categories: [LogCategory]) -> [LogCategory] {
        switch self {
        case .custom:
            return categories.sorted { $0.sortOrder < $1.sortOrder }
        case .mostUsed:
            return categories.sorted {
                if $0.tapCount != $1.tapCount { return $0.tapCount > $1.tapCount }
                return $0.sortOrder < $1.sortOrder
            }
        case .alphabetical:
            return categories.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }
}

enum CategoryViewStyle: String, CaseIterable, Identifiable {
    case grid, compact, list
    var id: String { rawValue }

    var label: String {
        switch self {
        case .grid: "Grid"
        case .compact: "Compact"
        case .list: "List"
        }
    }

    var systemImage: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .compact: "square.grid.3x3"
        case .list: "list.bullet"
        }
    }
}
