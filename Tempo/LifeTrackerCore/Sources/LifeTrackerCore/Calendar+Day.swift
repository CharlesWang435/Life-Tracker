import Foundation

public extension Calendar {
    /// Returns the start of the next day. Falls back to `startOfDay + 86400s` if
    /// Calendar can't compute the result (theoretical overflow / extreme timezones).
    func endOfDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        return self.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
    }
}
