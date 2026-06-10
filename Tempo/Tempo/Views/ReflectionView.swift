import SwiftUI
import SwiftData
import PhotosUI
import LifeTrackerCore

/// The evening reflection check-in for a single day. Shows the day's real timeline +
/// totals at the top (reflection grounded in data), then mood / energy / highlight / note.
/// Saving stamps `reflectedAt`, which drives the reflection streak.
struct ReflectionView: View {
    let date: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var mood: Int?
    @State private var energy: Int?
    @State private var highlight: String = ""
    @State private var note = AttributedString("")
    @State private var noteSelection = AttributedTextSelection()
    @State private var entry: DayEntry?

    /// Filenames already persisted on disk that the user is keeping. Starts as the
    /// entry's saved photos; removing a thumbnail drops it here (deleted on Save).
    @State private var existingPhotos: [String] = []
    /// Newly picked images not yet written to disk (written on Save, discarded on Cancel).
    @State private var newPhotos: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []

    @Query private var sessions: [Session]
    @Query(sort: \LogCategory.sortOrder) private var allCategories: [LogCategory]
    private let dayStart: Date
    private let dayEnd: Date

    init(date: Date) {
        self.date = date
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.endOfDay(for: date)
        self.dayStart = start
        self.dayEnd = end
        _sessions = Query(
            filter: #Predicate<Session> { $0.startDate >= start && $0.startDate < end },
            sort: \Session.startDate,
            order: .reverse
        )
    }

    private var hasSessions: Bool {
        sessions.contains { $0.category != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. Grounding — what actually happened today.
                if hasSessions {
                    VStack(alignment: .leading, spacing: 16) {
                        DayTimelineBar(sessions: sessions, dayStart: dayStart, dayEnd: dayEnd)
                        CategoryTotals(sessions: sessions)
                    }
                } else {
                    Text("No sessions logged for this day.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // Intended-vs-actual: what you planned this morning, and what you did.
                if let intended = entry?.intendedCategoryIDs, !intended.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your plan")
                            .font(.headline)
                        IntentionChips(categories: allCategories, intendedIDs: intended, sessions: sessions)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                // 2. Mood + energy.
                RatingRow(title: ReflectionAxis.mood.label, selection: $mood, labels: ReflectionAxis.mood.emojis)
                RatingRow(title: ReflectionAxis.energy.label, selection: $energy, labels: ReflectionAxis.energy.emojis)

                // 3. Highlight + note.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Highlight of the day")
                        .font(.headline)
                    TextField("One thing worth remembering…", text: $highlight, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Journal")
                        .font(.headline)
                    TextEditor(text: $note, selection: $noteSelection)
                        .frame(minHeight: 200)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // 4. Photos — visual memory of the day. Stored on-device only.
                photosSection
            }
            .padding()
        }
        .onChange(of: pickerItems) { _, items in loadPicked(items) }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveAndDismiss() }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Photos

    private let photoSize: CGFloat = 88

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(existingPhotos, id: \.self) { filename in
                        if let image = PhotoStorage.load(filename) {
                            photoThumb(image) { existingPhotos.removeAll { $0 == filename } }
                        }
                    }
                    ForEach(Array(newPhotos.enumerated()), id: \.offset) { index, image in
                        photoThumb(image) { newPhotos.remove(at: index) }
                    }
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2)
                            Text("Add")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: photoSize, height: photoSize)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Add photos")
                }
            }
        }
    }

    /// A square photo thumbnail with a corner remove button.
    private func photoThumb(_ image: UIImage, onRemove: @escaping () -> Void) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: photoSize, height: photoSize)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .font(.title3)
                }
                .padding(4)
                .accessibilityLabel("Remove photo")
            }
    }

    /// Decode the picked items into in-memory images, then clear the picker selection.
    private func loadPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var loaded: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loaded.append(image)
                }
            }
            await MainActor.run {
                newPhotos.append(contentsOf: loaded)
                pickerItems = []
            }
        }
    }

    private func load() {
        let e = DayEntryActions.entry(for: date, in: context)
        entry = e
        mood = e.moodRating
        energy = e.energyRating
        highlight = e.highlight ?? ""
        note = e.attributedNote
        existingPhotos = e.photoFilenames
    }

    private func saveAndDismiss() {
        guard let entry else { return }
        entry.moodRating = mood
        entry.energyRating = energy
        entry.highlight = highlight.trimmed.isEmpty ? nil : highlight.trimmed
        entry.attributedNote = note   // updates both noteData and the plain `note` mirror

        // Delete files the user removed, write newly picked ones, then store the filenames.
        for removed in entry.photoFilenames where !existingPhotos.contains(removed) {
            PhotoStorage.delete(removed)
        }
        let savedNew = newPhotos.compactMap { PhotoStorage.save($0) }
        entry.photoFilenames = existingPhotos + savedNew

        DayEntryActions.saveReflection(entry, in: context)
        Haptics.success()
        dismiss()
    }
}

/// A 1–5 selector rendered as five tappable emoji chips. Tapping the current value clears it,
/// so the rating stays optional. Writes the 1-based rating into `selection`.
struct RatingRow: View {
    let title: String
    @Binding var selection: Int?
    let labels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            HStack(spacing: 8) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    let value = index + 1
                    let isSelected = selection == value
                    Button {
                        selection = isSelected ? nil : value
                    } label: {
                        Text(label)
                            .font(.title2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor, lineWidth: isSelected ? 2 : 0)
                            )
                            .opacity(isSelected || selection == nil ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isSelected)
                }
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    NavigationStack {
        ReflectionView(date: .now)
    }
    .modelContainer(try! TempoModelContainer.makePreview())
}
