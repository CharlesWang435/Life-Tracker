//
//  ContentView.swift
//  Tempo Watch App Watch App
//
//  Created by Charles Wang on 5/29/26.
//

import SwiftUI
import SwiftData
import Charts
import LifeTrackerCore

/// Swipe (or Digital Crown) between the timer and the glanceable charts,
/// the same paging feel as the native Sleep / Weather watch apps.
struct ContentView: View {
    var body: some View {
        TabView {
            TimerTab()
            TodayChartTab()
            WeekChartTab()
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Timer tab

private struct TimerTab: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]
    @Query(filter: #Predicate<Session> { $0.endDate == nil })
    private var activeSessions: [Session]

    @State private var lastTapID = UUID()

    private var activeSession: Session? { activeSessions.first }

    // ~3 icons per row on a 46mm watch, fewer on smaller models.
    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 8)]

    private func handleTap(_ category: LogCategory) {
        lastTapID = UUID()
        if activeSession?.category?.id == category.id {
            SessionActions.stopActive(in: context)
        } else {
            SessionActions.start(category: category, in: context)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if let session = activeSession, let category = session.category {
                        ActiveTimerRow(session: session, category: category) {
                            SessionActions.stopActive(in: context)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(categories) { category in
                            CategoryIcon(
                                category: category,
                                isActive: activeSession?.category?.id == category.id
                            ) {
                                handleTap(category)
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .navigationTitle("Tempo")
            .sensoryFeedback(.impact(weight: .medium), trigger: lastTapID)
        }
    }
}

/// Live-updating header for the running session. Tapping the row stops it.
private struct ActiveTimerRow: View {
    let session: Session
    let category: LogCategory
    let onStop: () -> Void

    var body: some View {
        Button(action: onStop) {
            HStack(spacing: 10) {
                Image(systemName: category.sfSymbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: category.colorHex))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.name)
                        .font(.headline)
                        .lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text(session.elapsed(asOf: timeline.date).formattedDigital)
                            .font(.system(.subheadline, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color(hex: category.colorHex))
                    }
                }

                Spacer()

                Image(systemName: "stop.fill")
                    .foregroundStyle(.red)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: session.id)
    }
}

/// A compact circular icon button used to start (or switch to) a timer.
/// Sized so several fit per row without scrolling.
private struct CategoryIcon: View {
    let category: LogCategory
    let isActive: Bool
    let onTap: () -> Void

    private var color: Color { Color(hex: category.colorHex) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: category.sfSymbol)
                    .font(.body)
                    .foregroundStyle(isActive ? .white : color)
                    .frame(width: 46, height: 46)
                    .background(isActive ? color : color.opacity(0.18))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isActive ? color : .clear, lineWidth: 2)
                            .padding(-2)
                    )
                Text(category.name)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today chart tab (donut ring)

private struct TodayChartTab: View {
    @Query(sort: \Session.startDate, order: .reverse) private var sessions: [Session]

    private var todaySessions: [Session] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.endOfDay(for: .now)
        return sessions.filter { $0.startDate >= start && $0.startDate < end }
    }

    private var totals: [CategoryTotal] { SessionAggregates.categoryTotals(todaySessions) }
    private var grandTotal: TimeInterval { SessionAggregates.grandTotal(todaySessions) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if totals.isEmpty {
                    EmptyStatePlaceholder(
                        text: "Nothing tracked today",
                        systemImage: "chart.pie"
                    )
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Chart(totals) { item in
                                SectorMark(
                                    angle: .value("Time", item.duration),
                                    innerRadius: .ratio(0.62),
                                    angularInset: 2
                                )
                                .cornerRadius(3)
                                .foregroundStyle(Color(hex: item.category.colorHex))
                            }
                            .frame(height: 130)

                            VStack(spacing: 0) {
                                Text(grandTotal.formattedShort)
                                    .font(.system(.headline, design: .rounded).monospacedDigit())
                                Text("today")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(spacing: 6) {
                            ForEach(totals) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: item.category.colorHex))
                                        .frame(width: 8, height: 8)
                                    Text(item.category.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.duration.formattedShort)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .navigationTitle("Today")
        }
    }
}

// MARK: - Week chart tab (stacked bars)

private struct WeekChartTab: View {
    @Query(sort: \Session.startDate, order: .reverse) private var sessions: [Session]

    private var bars: [DailyCategoryTotal] {
        SessionAggregates.dailyCategoryTotals(sessions, days: 7)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if bars.isEmpty {
                    EmptyStatePlaceholder(
                        text: "No data this week",
                        systemImage: "chart.bar"
                    )
                } else {
                    Chart(bars) { bar in
                        BarMark(
                            x: .value("Day", bar.day, unit: .day),
                            y: .value("Hours", bar.duration / 3600)
                        )
                        .foregroundStyle(Color(hex: bar.category.colorHex))
                        .cornerRadius(2)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let hours = value.as(Double.self) {
                                    Text("\(Int(hours))h")
                                }
                            }
                        }
                    }
                    .frame(height: 150)
                    .padding(.horizontal, 4)
                }
            }
            .navigationTitle("7 days")
        }
    }
}

// MARK: - Shared empty state

private struct EmptyStatePlaceholder: View {
    let text: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

#Preview {
    let container = try! TempoModelContainer.makePreview()
    DefaultCategories.seedIfNeeded(in: container.mainContext)
    return ContentView()
        .modelContainer(container)
}
