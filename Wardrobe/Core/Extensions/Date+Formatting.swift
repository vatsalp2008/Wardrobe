import Foundation

extension Date {
    /// "Jun 15" style short label for wear history and metadata.
    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }

    /// Whole days between this date and now (always non-negative).
    var daysAgo: Int {
        let days = Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
        return max(0, days)
    }

    /// True if the date falls within the last `days` days. Used for recent-wear avoidance (spec §5.2).
    func isWithinLast(days: Int) -> Bool {
        daysAgo < days
    }

    /// The current season for the date, Northern-Hemisphere meteorological seasons.
    var season: Season {
        let month = Calendar.current.component(.month, from: self)
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .fall
        default: return .winter
        }
    }
}
