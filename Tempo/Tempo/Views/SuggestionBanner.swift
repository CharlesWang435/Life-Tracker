import SwiftUI
import LifeTrackerCore

/// Calendar-driven suggestion shown atop the Today screen:
/// a permission prompt until the user opts in, then a "Start X?" card when an
/// event matches a category. Hidden when the suggested timer is already running.
struct SuggestionBanner: View {
    let categories: [LogCategory]
    let activeCategoryID: UUID?

    @Environment(\.modelContext) private var context
    @State private var service = CalendarSuggestionService()
    @State private var suggestion: TimerSuggestion?

    var body: some View {
        Group {
            if service.needsPermissionPrompt {
                enablePrompt
            } else if let suggestion, suggestion.category.id != activeCategoryID {
                card(for: suggestion)
            }
        }
        .task(id: activeCategoryID) { refresh() }
    }

    private func refresh() {
        let result = service.suggestion(categories: categories)
        suggestion = result
        // Mirror to the App Group + push to the watch so its Smart Stack can show it.
        ConnectivityService.shared.broadcastSuggestion(result.map(SuggestionSnapshot.init(from:)))
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
                    await service.requestAccess()
                    refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func card(for suggestion: TimerSuggestion) -> some View {
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
                refresh()
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
