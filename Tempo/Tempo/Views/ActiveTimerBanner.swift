import SwiftUI
import LifeTrackerCore

struct ActiveTimerBanner: View {
    let activeSession: Session?
    @Environment(\.modelContext) private var context

    var body: some View {
        if let session = activeSession, let category = session.category {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                HStack(spacing: 14) {
                    Image(systemName: category.sfSymbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: category.colorHex))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.headline)
                        Text(session.elapsed(asOf: timeline.date).formattedDigital)
                            .font(.system(.title3, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color(hex: category.colorHex))
                    }

                    Spacer()

                    Button {
                        SessionActions.stopActive(in: context)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: session.id)
                }
                .padding(14)
                .background(Color(hex: category.colorHex).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: category.colorHex).opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.secondary)
                Text("Nothing running")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}
