import SwiftUI

struct SFSymbolPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    private let symbols: [String] = [
        // Sleep / rest
        "moon.zzz.fill", "bed.double.fill", "powersleep",
        // Work / study
        "laptopcomputer", "briefcase.fill", "graduationcap.fill", "book.fill",
        "pencil", "doc.text.fill", "studentdesk",
        // Exercise
        "figure.run", "figure.walk", "figure.yoga",
        "figure.strengthtraining.traditional", "dumbbell.fill", "bicycle",
        // Food
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill",
        "cart.fill", "bag.fill",
        // Social
        "person.2.fill", "person.3.fill", "bubble.left.and.bubble.right.fill",
        "phone.fill", "envelope.fill",
        // Transit
        "car.fill", "tram.fill", "airplane",
        // Leisure
        "sofa.fill", "gamecontroller.fill", "tv.fill",
        "music.note", "headphones", "guitars.fill",
        "paintbrush.fill", "camera.fill",
        // Home / errands
        "house.fill", "shower.fill", "washer.fill",
        "leaf.fill", "pawprint.fill",
        // Generic
        "heart.fill", "star.fill", "flame.fill",
        "tag.fill", "bookmark.fill", "flag.fill",
        "clock.fill", "calendar"
    ]

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selection = symbol
                            dismiss()
                        } label: {
                            Image(systemName: symbol)
                                .font(.title2)
                                .foregroundStyle(.primary)
                                .frame(width: 56, height: 56)
                                .background(
                                    selection == symbol
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.gray.opacity(0.1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selection == symbol ? Color.accentColor : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
