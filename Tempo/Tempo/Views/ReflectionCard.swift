import SwiftUI
import SwiftData
import LifeTrackerCore

/// Today-screen entry point for the reflection ritual. Two states:
/// - not yet reflected → a prompt to reflect, with the current streak badge
/// - already reflected → a compact summary (mood + highlight), tappable to edit
struct ReflectionCard: View {
    /// When set (on the Home dashboard), the card fills this fixed height to match other
    /// modules. Left nil on the Today screen, where it stays compact.
    var minHeight: CGFloat? = nil

    @Query(filter: #Predicate<DayEntry> { $0.reflectedAt != nil })
    private var reflectedEntries: [DayEntry]

    @Query private var todayEntries: [DayEntry]

    @State private var showSheet = false

    init(minHeight: CGFloat? = nil) {
        self.minHeight = minHeight
        let todayStart = Calendar.current.startOfDay(for: .now)
        _todayEntries = Query(filter: #Predicate<DayEntry> { $0.date == todayStart })
    }

    private var todayEntry: DayEntry? { todayEntries.first }
    private var isReflectedToday: Bool { todayEntry?.isReflected ?? false }

    private var streak: Int {
        ReflectionStreak.current(reflectedDays: reflectedEntries.map(\.date))
    }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isReflectedToday ? "moon.stars.fill" : "moon.stars")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.indigo)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    if isReflectedToday {
                        Text(reflectedSummaryTitle)
                            .font(.headline)
                        if let highlight = todayEntry?.highlight, !highlight.isEmpty {
                            Text(highlight)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("Tap to edit your reflection.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Reflect on today")
                            .font(.headline)
                        Text("How did today feel?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if streak > 0 {
                    streakBadge
                } else if !isReflectedToday {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: minHeight, alignment: .topLeading)
            .background(Color.indigo.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.indigo.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            NavigationStack { ReflectionView(date: .now) }
        }
    }

    private var reflectedSummaryTitle: String {
        if let mood = todayEntry?.moodRating, let emoji = ReflectionAxis.mood.emoji(for: mood) {
            return "Reflected \(emoji)"
        }
        return "Reflected"
    }

    private var streakBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
            Text("\(streak)")
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.12))
        .clipShape(Capsule())
    }
}
