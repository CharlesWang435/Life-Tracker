import SwiftUI
import LifeTrackerCore

struct ActiveTimerBanner: View {
    let activeSession: Session?
    /// When set (on the Home dashboard), the banner fills this fixed height so it matches
    /// other modules. Left nil on the Today screen, where it stays compact.
    var minHeight: CGFloat? = nil
    @Environment(\.modelContext) private var context
    @AppStorage("capture.noteOnStop") private var noteOnStop = false
    @State private var noteSession: Session?
    @State private var showingNote = false

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
                        if noteOnStop {
                            noteSession = session
                            showingNote = true
                        }
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
                .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: minHeight, alignment: .topLeading)
                .background(Color(hex: category.colorHex).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: category.colorHex).opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .sheet(isPresented: $showingNote) {
                if let noteSession {
                    QuickNoteSheet(session: noteSession)
                }
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
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: minHeight, alignment: .topLeading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}
