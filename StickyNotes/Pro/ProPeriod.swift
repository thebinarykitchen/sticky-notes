import Foundation

/// The calendar month a usage count belongs to, as `year * 12 + month - 1`.
///
/// Calendar months rather than a rolling window, matching the "resets on the first" copy in
/// ``ProFeature/explanation``.
nonisolated enum ProPeriod {
    /// The month stamp for `date`.
    static func stamp(for date: Date, in calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return (parts.year ?? 0) * 12 + (parts.month ?? 1) - 1
    }

    static var current: Int { stamp(for: .now) }

    /// `count` if it was stamped in month `now`, otherwise 0. The reset happens on read, so
    /// nothing needs to run at the month boundary.
    static func carried(_ count: Int, stamped: Int?, into now: Int) -> Int {
        stamped == now ? count : 0
    }
}
