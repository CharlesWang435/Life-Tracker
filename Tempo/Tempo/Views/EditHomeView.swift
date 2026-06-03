import SwiftUI

/// Customize the Home dashboard: reorder/remove enabled tiles, resize them (S/M/L),
/// and add available modules. Edits write straight back through the binding, so Home
/// updates live.
struct EditHomeView: View {
    @Binding var tiles: [HomeTile]
    @Environment(\.dismiss) private var dismiss

    /// Modules not currently on Home, in canonical order.
    private var available: [HomeModule] {
        let present = Set(tiles.map(\.module))
        return HomeModule.allCases.filter { !present.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if tiles.isEmpty {
                        Text("No modules on Home. Add some below.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tiles) { tile in
                            row(for: tile)
                        }
                        .onMove { from, to in
                            tiles.move(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { offsets in
                            tiles.remove(atOffsets: offsets)
                        }
                    }
                } header: {
                    Text("On Home")
                } footer: {
                    Text("Drag to reorder · swipe to remove · tap the size to resize.")
                }

                if !available.isEmpty {
                    Section("Add to Home") {
                        ForEach(available) { module in
                            Button {
                                tiles.append(HomeTile(module: module, size: module.defaultSize))
                            } label: {
                                Label(module.title, systemImage: module.systemImage)
                                    .foregroundStyle(.primary)
                                    .badge(Text(Image(systemName: "plus.circle.fill")))
                            }
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Edit Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for tile: HomeTile) -> some View {
        HStack {
            Label(tile.module.title, systemImage: tile.module.systemImage)
            Spacer()
            if tile.module.allowedSizes.count > 1 {
                sizeMenu(for: tile)
            }
        }
    }

    private func sizeMenu(for tile: HomeTile) -> some View {
        Menu {
            ForEach(tile.module.allowedSizes) { size in
                Button {
                    setSize(size, for: tile)
                } label: {
                    Label(size.label, systemImage: tile.size == size ? "checkmark" : size.systemImage)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tile.size.systemImage)
                Text(tile.size.label)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
        }
    }

    private func setSize(_ size: HomeModuleSize, for tile: HomeTile) {
        guard let index = tiles.firstIndex(where: { $0.id == tile.id }) else { return }
        tiles[index].size = size
    }
}

#Preview {
    EditHomeView(tiles: .constant(HomeLayout.defaultTiles))
}
