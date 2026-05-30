import SwiftUI
import SwiftData
import LifeTrackerCore

struct SessionList: View {
    let sessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sessions")
                .font(.headline)
            if sessions.isEmpty {
                Text("No sessions yet. Tap a category to start.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(sessions) { session in
                    NavigationLink {
                        ManualSessionEditor(session: session)
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            if let category = session.category {
                Image(systemName: category.sfSymbol)
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: category.colorHex))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name).font(.callout)
                    Text(timeRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(session.elapsed().formattedShort)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("(deleted category)")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var timeRangeText: String {
        let start = session.startDate.formatted(date: .omitted, time: .shortened)
        if let end = session.endDate {
            return "\(start) – \(end.formatted(date: .omitted, time: .shortened))"
        }
        return "\(start) – now"
    }
}

struct CategoryTotals: View {
    let sessions: [Session]

    private var totals: [(category: LogCategory, duration: TimeInterval)] {
        let groups = Dictionary(grouping: sessions, by: { $0.category?.id })
        return groups.compactMap { _, items in
            guard let category = items.first?.category else { return nil }
            let total = items.reduce(0.0) { $0 + $1.elapsed() }
            return (category, total)
        }
        .sorted { $0.duration > $1.duration }
    }

    var body: some View {
        if !totals.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Totals")
                    .font(.headline)
                ForEach(totals, id: \.category.id) { entry in
                    HStack {
                        Circle()
                            .fill(Color(hex: entry.category.colorHex))
                            .frame(width: 10, height: 10)
                        Text(entry.category.name)
                        Spacer()
                        Text(entry.duration.formattedShort)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
    }
}
