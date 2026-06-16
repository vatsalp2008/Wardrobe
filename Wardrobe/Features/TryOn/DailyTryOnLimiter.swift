import Foundation

/// Enforces a daily cap on try-on generations for cost control (spec §5.3: ~5 free/day,
/// each Replicate run ~$0.01). Counts are stored in `UserDefaults`, keyed by calendar day.
struct DailyTryOnLimiter {
    static let dailyLimit = 5

    private let defaults: UserDefaults
    private let countKey = "tryon.daily.count"
    private let dayKey = "tryon.daily.day"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var todayKey: Int {
        Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
    }

    /// Usages remaining today.
    func remaining() -> Int {
        max(0, Self.dailyLimit - currentCount())
    }

    func canGenerate() -> Bool {
        remaining() > 0
    }

    /// Records one generation against today's quota.
    func record() {
        defaults.set(todayKey, forKey: dayKey)
        defaults.set(currentCount() + 1, forKey: countKey)
    }

    private func currentCount() -> Int {
        guard defaults.integer(forKey: dayKey) == todayKey else { return 0 }  // new day → reset
        return defaults.integer(forKey: countKey)
    }
}
