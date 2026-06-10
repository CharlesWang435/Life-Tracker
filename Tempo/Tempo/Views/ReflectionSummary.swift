import SwiftUI
import LifeTrackerCore

/// A horizontal strip of read-only reflection photos, loaded from `PhotoStorage`.
/// Renders nothing when there are no filenames.
struct ReflectionPhotoStrip: View {
    let filenames: [String]
    var size: CGFloat = 96

    var body: some View {
        if !filenames.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(filenames, id: \.self) { filename in
                        if let image = PhotoStorage.load(filename) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }
}

/// A read-only summary of a day's reflection: mood/energy, highlight, journal note,
/// and photos. Used when browsing history (day detail), distinct from the editable
/// `ReflectionView`. Renders nothing if the entry has no reflective content.
struct ReflectionSummaryCard: View {
    let entry: DayEntry

    private var hasContent: Bool {
        entry.moodRating != nil
            || entry.energyRating != nil
            || !(entry.highlight ?? "").isEmpty
            || !(entry.note ?? "").isEmpty
            || !entry.photoFilenames.isEmpty
    }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reflection")
                    .font(.headline)

                HStack(spacing: 20) {
                    if let mood = entry.moodRating {
                        ratingChip(axis: .mood, value: mood)
                    }
                    if let energy = entry.energyRating {
                        ratingChip(axis: .energy, value: energy)
                    }
                }

                if let highlight = entry.highlight, !highlight.isEmpty {
                    Label {
                        Text(highlight).font(.subheadline)
                    } icon: {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                    }
                }

                if let note = entry.note, !note.isEmpty {
                    Text(entry.attributedNote)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ReflectionPhotoStrip(filenames: entry.photoFilenames)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.indigo.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func ratingChip(axis: ReflectionAxis, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(axis.emoji(for: value) ?? "")
                .font(.title2)
            Text(axis.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
