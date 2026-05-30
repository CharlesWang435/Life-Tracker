import SwiftUI
import SwiftData
import LifeTrackerCore

struct CategoryPicker: View {
    let categories: [LogCategory]
    let style: CategoryViewStyle
    let todaySessions: [Session]

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Session> { $0.endDate == nil })
    private var activeSessions: [Session]

    var body: some View {
        switch style {
        case .grid:
            CategoryGrid(categories: categories, activeID: activeID, onTap: handleTap)
        case .compact:
            CompactCategoryGrid(categories: categories, activeID: activeID, onTap: handleTap)
        case .list:
            CategoryListLayout(
                categories: categories,
                activeID: activeID,
                todaySessions: todaySessions,
                onTap: handleTap
            )
        }
    }

    private var activeID: UUID? { activeSessions.first?.category?.id }

    private func handleTap(_ category: LogCategory) {
        if activeID == category.id {
            SessionActions.stopActive(in: context)
        } else {
            SessionActions.start(category: category, in: context)
        }
    }
}

// MARK: - Grid (current default — 3-column cards)

struct CategoryGrid: View {
    let categories: [LogCategory]
    let activeID: UUID?
    let onTap: (LogCategory) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(categories) { category in
                CategoryCard(
                    category: category,
                    isActive: activeID == category.id,
                    onTap: { onTap(category) }
                )
            }
        }
    }
}

struct CategoryCard: View {
    let category: LogCategory
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: category.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(isActive ? .white : Color(hex: category.colorHex))
                    .frame(width: 44, height: 44)
                    .background(
                        isActive
                            ? Color(hex: category.colorHex)
                            : Color(hex: category.colorHex).opacity(0.15)
                    )
                    .clipShape(Circle())
                Text(category.name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isActive ? Color(hex: category.colorHex).opacity(0.10) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isActive ? Color(hex: category.colorHex) : Color.gray.opacity(0.2),
                        lineWidth: isActive ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact (small icons, more per row)

struct CompactCategoryGrid: View {
    let categories: [LogCategory]
    let activeID: UUID?
    let onTap: (LogCategory) -> Void

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(categories) { category in
                let isActive = activeID == category.id
                Button {
                    onTap(category)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: category.sfSymbol)
                            .font(.body)
                            .foregroundStyle(isActive ? .white : Color(hex: category.colorHex))
                            .frame(width: 36, height: 36)
                            .background(
                                isActive
                                    ? Color(hex: category.colorHex)
                                    : Color(hex: category.colorHex).opacity(0.15)
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        isActive ? Color(hex: category.colorHex) : .clear,
                                        lineWidth: 2
                                    )
                                    .padding(-3)
                            )
                        Text(category.name)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - List (one per row, with today's total inline)

struct CategoryListLayout: View {
    let categories: [LogCategory]
    let activeID: UUID?
    let todaySessions: [Session]
    let onTap: (LogCategory) -> Void

    private func todayTotal(for category: LogCategory) -> TimeInterval {
        todaySessions
            .filter { $0.category?.id == category.id }
            .reduce(0.0) { $0 + $1.elapsed() }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(categories) { category in
                let isActive = activeID == category.id
                let total = todayTotal(for: category)
                Button {
                    onTap(category)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.sfSymbol)
                            .font(.body)
                            .foregroundStyle(isActive ? .white : Color(hex: category.colorHex))
                            .frame(width: 36, height: 36)
                            .background(
                                isActive
                                    ? Color(hex: category.colorHex)
                                    : Color(hex: category.colorHex).opacity(0.15)
                            )
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(.callout)
                                .foregroundStyle(.primary)
                            if total > 0 {
                                Text("\(total.formattedShort) today")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if category.tapCount > 0 {
                                Text("\(category.tapCount) total taps")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Image(systemName: isActive ? "stop.circle.fill" : "play.circle")
                            .font(.title3)
                            .foregroundStyle(isActive ? .red : Color(hex: category.colorHex))
                    }
                    .padding(12)
                    .background(isActive ? Color(hex: category.colorHex).opacity(0.10) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isActive ? Color(hex: category.colorHex) : Color.gray.opacity(0.2),
                                lineWidth: isActive ? 2 : 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
