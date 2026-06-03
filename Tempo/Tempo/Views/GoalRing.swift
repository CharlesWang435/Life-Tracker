import SwiftUI
import LifeTrackerCore

/// A circular progress ring for one goal. Fills with the category color; a met target
/// shows a checkmark, an exceeded cap turns red with a warning glyph.
struct GoalRing: View {
    let status: GoalStatus
    let color: Color
    let symbol: String
    var size: CGFloat = 56
    var lineWidth: CGFloat = 7

    private var ringColor: Color {
        (status.direction == .atMost && status.isOver) ? .red : color
    }

    private var centerSymbol: String {
        if status.direction == .atLeast && status.isMet { return "checkmark" }
        if status.direction == .atMost && status.isOver { return "exclamationmark" }
        return symbol
    }

    var body: some View {
        ZStack {
            // Inset by half the line width so the centered stroke stays inside the frame
            // (otherwise the ring's outer edge is clipped).
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: status.clampedFraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: centerSymbol)
                .font(.system(size: size * 0.3, weight: .semibold))
                .foregroundStyle(ringColor)
        }
        .frame(width: size, height: size)
    }
}

/// A horizontal strip of goal rings for every category that has a goal. Renders nothing
/// when no category has a goal — callers can check `GoalRingsView.hasGoals(in:)` first
/// if they want to show a header or skip layout entirely.
struct GoalRingsView: View {
    let categories: [LogCategory]
    let sessions: [Session]
    var ringSize: CGFloat = 56

    private var goaled: [(category: LogCategory, status: GoalStatus)] {
        categories.compactMap { category in
            GoalEvaluator.status(for: category, sessions: sessions).map { (category, $0) }
        }
    }

    static func hasGoals(in categories: [LogCategory]) -> Bool {
        categories.contains { $0.hasGoal }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(goaled, id: \.category.id) { item in
                    VStack(spacing: 6) {
                        GoalRing(
                            status: item.status,
                            color: Color(hex: item.category.colorHex),
                            symbol: item.category.sfSymbol,
                            size: ringSize
                        )
                        Text(item.category.name)
                            .font(.caption)
                            .lineLimit(1)
                        Text("\(goalMinutesString(item.status.spent)) / \(goalMinutesString(item.status.target))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: ringSize + 30)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

/// Whole-minute friendly duration for goals (e.g. "45m", "1h", "1h 30m") — avoids the
/// seconds tier of `formattedShort` since goals are set in whole minutes.
func goalMinutesString(_ seconds: TimeInterval) -> String {
    let minutes = Int((seconds / 60).rounded())
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    let remainder = minutes % 60
    return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
}
