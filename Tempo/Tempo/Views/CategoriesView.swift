import SwiftUI
import SwiftData
import LifeTrackerCore

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]
    @State private var showingNewCategory = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    NavigationLink {
                        CategoryEditorView(category: category)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.sfSymbol)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color(hex: category.colorHex))
                                .clipShape(Circle())
                            Text(category.name)
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                NavigationStack {
                    CategoryEditorView(category: nil, existingCount: categories.count)
                }
            }
        }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
        SessionActions.save(context)
    }

    private func delete(at offsets: IndexSet) {
        for offset in offsets {
            CategoryActions.delete(categories[offset], in: context)
        }
    }
}
