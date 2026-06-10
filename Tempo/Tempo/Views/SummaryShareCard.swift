import SwiftUI
import LifeTrackerCore

/// The data behind a shareable summary image — kept plain so both the weekly
/// review and a single day can build one.
struct SummaryShareModel {
    struct Row: Identifiable {
        let id = UUID()
        let name: String
        let colorHex: String
        let fraction: Double      // 0...1 of the period total
        let valueString: String
    }

    let title: String             // "This Week" / "Tuesday, Jun 10"
    let totalString: String       // "12h 30m"
    let subtitle: String?         // delta, highlight, or streak
    let rows: [Row]               // top categories
    let accentEmoji: String?      // mood, if known
}

/// A branded, fixed-width card rendered offscreen to a shareable image. Uses fixed
/// widths and explicit colors so `ImageRenderer` produces a consistent result
/// regardless of the device's appearance.
struct SummaryShareCard: View {
    let model: SummaryShareModel

    private let cardWidth: CGFloat = 360
    private var barWidth: CGFloat { cardWidth - 40 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Tempo", systemImage: "timer")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.indigo)
                Spacer()
                if let emoji = model.accentEmoji {
                    Text(emoji).font(.largeTitle)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(model.totalString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                Text("tracked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let subtitle = model.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(model.rows) { row in
                    let color = Color(hex: row.colorHex)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.black)
                            Spacer()
                            Text(row.valueString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ZStack(alignment: .leading) {
                            Capsule().fill(color.opacity(0.15))
                                .frame(width: barWidth, height: 10)
                            Capsule().fill(color)
                                .frame(width: max(8, CGFloat(row.fraction) * barWidth), height: 10)
                        }
                    }
                }
            }

            Text("Made with Tempo")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: cardWidth, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

/// A toolbar-friendly share control: renders `model` to an image offscreen, then
/// offers a system share sheet. Shows a spinner until the image is ready.
struct SummaryShareLink: View {
    let model: SummaryShareModel
    @State private var rendered: Image?

    var body: some View {
        Group {
            if let rendered {
                ShareLink(
                    item: rendered,
                    preview: SharePreview(model.title, image: rendered)
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            } else {
                ProgressView()
            }
        }
        .task(id: model.title) { render() }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: SummaryShareCard(model: model))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            rendered = Image(uiImage: uiImage)
        }
    }
}
