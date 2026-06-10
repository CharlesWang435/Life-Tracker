import SwiftUI
import SwiftData
import LifeTrackerCore

/// A timer suggestion shown atop the Today screen, drawn from two on-device signals:
/// your calendar (an event matching a category) and your location (you've arrived at
/// a tagged place). Shows a calendar permission prompt until you opt in; hidden when
/// the suggested timer is already running.
///
/// Ranking when both fire: a calendar event happening *now* wins, then a location
/// match ("you're here"), then an upcoming calendar event.
struct SuggestionBanner: View {
    let categories: [LogCategory]
    let activeCategoryID: UUID?

    @Environment(\.modelContext) private var context
    @Query(sort: \Place.createdAt) private var places: [Place]

    @State private var calendarService = CalendarSuggestionService()
    @State private var location = LocationService()
    @State private var active: ActiveSuggestion?

    /// A source-agnostic suggestion the banner can render and broadcast.
    private struct ActiveSuggestion {
        let category: LogCategory
        let reason: String
        let snapshot: SuggestionSnapshot
    }

    var body: some View {
        Group {
            if calendarService.needsPermissionPrompt {
                enablePrompt
            } else if let active, active.category.id != activeCategoryID {
                card(for: active)
            }
        }
        .task(id: activeCategoryID) { await refresh() }
    }

    private func refresh() async {
        let calendar = calendarService.suggestion(categories: categories)

        var place: PlaceSuggestion?
        if !places.isEmpty, location.isAuthorized,
           let coordinate = await location.requestCoordinate() {
            place = PlaceSuggester.suggestion(at: coordinate, places: places, categories: categories)
        }

        let chosen = best(calendar: calendar, place: place)
        active = chosen
        // Mirror to the App Group + push to the watch so its Smart Stack can show it.
        ConnectivityService.shared.broadcastSuggestion(chosen?.snapshot)
    }

    /// Rank the two signals: a calendar event on *now* beats a location match,
    /// which beats an upcoming calendar event.
    private func best(calendar: TimerSuggestion?, place: PlaceSuggestion?) -> ActiveSuggestion? {
        if let calendar, calendar.isHappeningNow {
            return ActiveSuggestion(category: calendar.category, reason: calendar.reason, snapshot: SuggestionSnapshot(from: calendar))
        }
        if let place {
            let validUntil = Date.now.addingTimeInterval(30 * 60)
            return ActiveSuggestion(category: place.category, reason: place.reason, snapshot: SuggestionSnapshot(from: place, validUntil: validUntil))
        }
        if let calendar {
            return ActiveSuggestion(category: calendar.category, reason: calendar.reason, snapshot: SuggestionSnapshot(from: calendar))
        }
        return nil
    }

    private var enablePrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar suggestions")
                    .font(.subheadline.weight(.semibold))
                Text("Let Tempo suggest a timer from your schedule.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Enable") {
                Task {
                    await calendarService.requestAccess()
                    await refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func card(for suggestion: ActiveSuggestion) -> some View {
        let color = Color(hex: suggestion.category.colorHex)
        return HStack(spacing: 12) {
            Image(systemName: suggestion.category.sfSymbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Start \(suggestion.category.name)?")
                    .font(.headline)
                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                SessionActions.start(category: suggestion.category, in: context)
                Task { await refresh() }
            } label: {
                Image(systemName: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: suggestion.category.id)
        }
        .padding(12)
        .background(color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
