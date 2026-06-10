import SwiftUI
import SwiftData
import LifeTrackerCore

/// A weekly recap: total time + change vs the prior week, per-day bars, category breakdown,
/// the mood arc, top highlights from reflections, and streaks. Reuses existing chart views.
struct WeeklyReviewView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Session.startDate) private var recentSessions: [Session]
    @Query(filter: #Predicate<DayEntry> { $0.reflectedAt != nil }, sort: \DayEntry.date, order: .reverse)
    private var reflections: [DayEntry]

    private let weekStart: Date
    private let prevWeekStart: Date

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        weekStart = cal.date(byAdding: .day, value: -6, to: today)!     // last 7 days incl. today
        prevWeekStart = cal.date(byAdding: .day, value: -13, to: today)!
    }

    private var weekSessions: [Session] {
        recentSessions.filter { $0.startDate >= weekStart }
    }
    private var prevWeekSessions: [Session] {
        recentSessions.filter { $0.startDate >= prevWeekStart && $0.startDate < weekStart }
    }
    private var weekReflections: [DayEntry] {
        reflections.filter { $0.date >= weekStart }
    }

    private var total: TimeInterval { SessionAggregates.grandTotal(weekSessions) }
    private var prevTotal: TimeInterval { SessionAggregates.grandTotal(prevWeekSessions) }
    private var delta: TimeInterval { total - prevTotal }

    private var moodPoints: [TrendPoint] {
        weekReflections
            .compactMap { entry -> TrendPoint? in
                guard let mood = entry.moodRating,
                      let emoji = ReflectionAxis.mood.emoji(for: mood) else { return nil }
                return TrendPoint(date: entry.date, rating: mood, emoji: emoji)
            }
            .sorted { $0.date < $1.date }
    }

    private var highlights: [DayEntry] {
        weekReflections.filter { ($0.highlight ?? "").isEmpty == false }
    }

    /// Every photo captured in this week's reflections, newest day first.
    private var weekPhotos: [String] {
        weekReflections
            .sorted { $0.date > $1.date }
            .flatMap(\.photoFilenames)
    }

    private var loggingStreak: Int { Streak.current(days: Streak.loggedDays(from: recentSessions)) }

    /// A shareable summary of the week: total, delta/streak, and top categories.
    private var shareModel: SummaryShareModel {
        let totals = SessionAggregates.categoryTotals(weekSessions)
        let rows = totals.prefix(3).map { item in
            SummaryShareModel.Row(
                name: item.category.name,
                colorHex: item.category.colorHex,
                fraction: total > 0 ? item.duration / total : 0,
                valueString: item.duration.formattedShort
            )
        }
        var subtitleParts: [String] = []
        if prevTotal > 0 {
            subtitleParts.append("\(delta >= 0 ? "↑" : "↓") \(abs(delta).formattedShort) vs last week")
        }
        if loggingStreak > 0 {
            subtitleParts.append("\(loggingStreak)-day streak")
        }
        let avgMood = moodPoints.isEmpty ? nil
            : Int((Double(moodPoints.map(\.rating).reduce(0, +)) / Double(moodPoints.count)).rounded())
        return SummaryShareModel(
            title: "This Week",
            totalString: total.formattedShort,
            subtitle: subtitleParts.joined(separator: " · "),
            rows: rows,
            accentEmoji: avgMood.flatMap { ReflectionAxis.mood.emoji(for: $0) }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if weekSessions.isEmpty {
                    ContentUnavailableView(
                        "Not enough yet",
                        systemImage: "calendar",
                        description: Text("Track a few days and your weekly review will appear here.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            headline
                            WeekBarChart(sessions: weekSessions)
                            TodayDonutChart(sessions: weekSessions, title: "Where your time went")
                            CategoryTotals(sessions: weekSessions)
                            if !moodPoints.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Mood this week").font(.headline)
                                    MoodTrendChart(points: moodPoints, tint: .indigo, height: 160)
                                }
                            }
                            if !highlights.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Highlights").font(.headline)
                                    ForEach(highlights) { entry in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text(entry.date.formatted(.dateTime.weekday(.abbreviated)))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 38, alignment: .leading)
                                            Text(entry.highlight ?? "")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                            }
                            if !weekPhotos.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Moments").font(.headline)
                                    ReflectionPhotoStrip(filenames: weekPhotos, size: 120)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Weekly Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !weekSessions.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        SummaryShareLink(model: shareModel)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(total.formattedShort + " tracked")
                .font(.title.weight(.bold))
            if prevTotal > 0 {
                Label(
                    "\(delta >= 0 ? "Up" : "Down") \(abs(delta).formattedShort) vs last week",
                    systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right"
                )
                .font(.subheadline)
                .foregroundStyle(delta >= 0 ? .green : .orange)
            }
            if loggingStreak > 0 {
                Label("\(loggingStreak)-day logging streak", systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
