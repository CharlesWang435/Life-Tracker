import SwiftUI
import SwiftData
import LifeTrackerCore

/// "You have untracked time — what were you doing?" Tap a category to backfill the gap
/// with a completed session. Shown on Today when nothing is running and a gap exists.
struct GapBackfillCard: View {
    let gap: UntrackedGap
    let categories: [LogCategory]
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var context
    @State private var showingSplit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.orange)
                Text("Untracked time")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            Text("\(goalMinutesString(gap.duration)) since \(gap.start.formatted(date: .omitted, time: .shortened)) — what were you doing?")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { category in
                        Button {
                            SessionActions.addCompleted(category: category, start: gap.start, end: gap.end, in: context)
                            Haptics.success()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.sfSymbol)
                                Text(category.name)
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: category.colorHex))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: category.colorHex).opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            Button {
                showingSplit = true
            } label: {
                Label("Split across categories…", systemImage: "rectangle.split.3x1")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .sheet(isPresented: $showingSplit) {
            GapFillView(gap: gap)
        }
        .padding(14)
        .background(.thinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Gentle "still running?" nudge for a timer that's been going a long time.
struct LongRunningNudge: View {
    let session: Session
    let elapsed: TimeInterval
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hourglass")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Still tracking \(session.category?.name ?? "this")?")
                    .font(.subheadline.weight(.semibold))
                Text("Running \(goalMinutesString(elapsed)) — stop it if you forgot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Stop") {
                SessionActions.stopActive(in: context)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.red)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(.thinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
