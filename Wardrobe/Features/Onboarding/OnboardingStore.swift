import Foundation

/// Tracks whether the first-run intro has been completed (spec §7.3). Persisted in
/// `UserDefaults`, mirroring `BudgetStore`.
///
/// `key` is exposed so `WardrobeApp` can bind to it with `@AppStorage` while this store stays
/// the single owner of the literal.
struct OnboardingStore {
    static let key = "settings.hasCompletedOnboarding"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        get {
            defaults.bool(forKey: Self.key)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Self.key)
        }
    }
}
