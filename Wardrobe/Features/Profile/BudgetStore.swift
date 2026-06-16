import Foundation

/// User's shopping budget for Gap Finder results (spec §7.1 Profile setting). Persisted in
/// `UserDefaults`; read by `GapFinderViewModel` when querying SerpAPI.
struct BudgetStore {
    static let `default` = 100
    private let key = "settings.gapfinder.budgetUSD"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var budgetUSD: Int {
        get {
            let value = defaults.integer(forKey: key)
            return value == 0 ? Self.default : value
        }
        nonmutating set {
            defaults.set(max(1, newValue), forKey: key)
        }
    }
}
