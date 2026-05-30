import SwiftUI
import LifeTrackerCore

struct DayTimelineBar: View {
    let sessions: [Session]
    let dayStart: Date
    let dayEnd: Date

    private var dayDuration: TimeInterval { dayEnd.timeIntervalSince(dayStart) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.12))
                    ForEach(sessions) { session in
                        if let category = session.category {
                            block(for: session, category: category, width: geo.size.width)
                        }
                    }
                }
            }
            .frame(height: 28)
            HStack {
                Text("12 AM").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Noon").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("12 AM").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func block(for session: Session, category: LogCategory, width: CGFloat) -> some View {
        let start = max(session.startDate, dayStart)
        let end = min(session.endDate ?? .now, dayEnd)
        if end > start {
            let startOffset = start.timeIntervalSince(dayStart) / dayDuration
            let length = end.timeIntervalSince(start) / dayDuration
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: category.colorHex))
                .frame(width: max(2, width * length))
                .offset(x: width * startOffset)
        }
    }
}
