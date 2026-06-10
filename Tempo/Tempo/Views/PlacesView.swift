import SwiftUI
import SwiftData
import LifeTrackerCore

/// Manage saved places that drive arrival-based suggestions. Each place pairs a
/// location (captured from where you are) with a category and a match radius.
struct PlacesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Place.createdAt) private var places: [Place]
    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]

    @State private var showingAdd = false
    @State private var editingPlace: Place?

    var body: some View {
        List {
            if places.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No places yet",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Add a place while you're there — Tempo will suggest its timer when you return.")
                    )
                }
            } else {
                Section {
                    ForEach(places) { place in
                        Button { editingPlace = place } label: {
                            row(place)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                } footer: {
                    Text("When you're within a place's radius, Tempo suggests starting its category on the Today screen.")
                }
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add place")
            }
        }
        .sheet(isPresented: $showingAdd) {
            PlaceEditorView()
        }
        .sheet(item: $editingPlace) { place in
            PlaceEditorView(place: place)
        }
    }

    private func row(_ place: Place) -> some View {
        let category = categories.first { $0.id == place.categoryID }
        return HStack(spacing: 12) {
            Image(systemName: category?.sfSymbol ?? "mappin")
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(category.map { Color(hex: $0.colorHex) } ?? .gray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.body)
                Text("\(category?.name ?? "No category") · within \(Int(place.radius)) m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            PlaceActions.delete(places[index], in: context)
        }
    }
}

/// Add or edit a place: capture/keep a location, name it, pick a category and radius.
struct PlaceEditorView: View {
    /// The place being edited, or nil when adding a new one.
    var place: Place?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]
    @State private var location = LocationService()

    @State private var name = ""
    @State private var categoryID: UUID?
    @State private var radius: Double = 120
    @State private var coordinate: GeoCoordinate?
    @State private var isLocating = false
    @State private var didLoad = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && categoryID != nil && coordinate != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Gym, Office)", text: $name)
                }

                Section("Category") {
                    Picker("Suggest", selection: $categoryID) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.sfSymbol)
                                .tag(UUID?.some(category.id))
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Match radius: \(Int(radius)) m")
                        Slider(value: $radius, in: 50...500, step: 10)
                    }
                } footer: {
                    Text("How close you must be for Tempo to consider you \"here\".")
                }

                Section {
                    locationRow
                } header: {
                    Text("Location")
                } footer: {
                    Text("Tempo saves the coordinates of where you are now. Your location never leaves your device.")
                }
            }
            .navigationTitle(place == nil ? "New Place" : "Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: location.isAuthorized) { _, authorized in
                if authorized && coordinate == nil { capture() }
            }
        }
    }

    @ViewBuilder
    private var locationRow: some View {
        if location.needsPermissionPrompt {
            Button("Allow location access") { location.requestAccess() }
        } else if !location.isAuthorized {
            Label("Location access is off. Enable it in iOS Settings to tag this place.", systemImage: "location.slash")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if coordinate != nil {
            HStack {
                Label("Current location captured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("Update") { capture() }
                    .font(.footnote)
            }
        } else {
            HStack {
                Text(isLocating ? "Locating…" : "Waiting for location")
                    .foregroundStyle(.secondary)
                Spacer()
                if isLocating { ProgressView() }
                else { Button("Retry") { capture() } }
            }
        }
    }

    /// Preload from the edited place, or set up a fresh add (default category + a fix).
    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let place {
            name = place.name
            categoryID = place.categoryID
            radius = place.radius
            coordinate = GeoCoordinate(latitude: place.latitude, longitude: place.longitude)
        } else {
            if categoryID == nil { categoryID = categories.first?.id }
            prepareLocation()
        }
    }

    /// Request access if needed, then grab a fix once authorized.
    private func prepareLocation() {
        if location.needsPermissionPrompt {
            location.requestAccess()
        }
        capture()
    }

    private func capture() {
        guard location.isAuthorized else { return }
        isLocating = true
        Task {
            let fix = await location.requestCoordinate()
            await MainActor.run {
                coordinate = fix
                isLocating = false
            }
        }
    }

    private func save() {
        guard let coordinate, let categoryID else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let place {
            place.name = trimmed
            place.categoryID = categoryID
            place.radius = radius
            place.latitude = coordinate.latitude
            place.longitude = coordinate.longitude
            PlaceActions.save(context)
        } else {
            PlaceActions.add(
                name: trimmed,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: radius,
                categoryID: categoryID,
                in: context
            )
        }
        Haptics.success()
        dismiss()
    }
}
