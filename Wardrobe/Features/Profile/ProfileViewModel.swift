import SwiftUI

/// Backs the Profile tab (spec §7.1): user-photo management, wear-history stats, notification
/// preference, and the Gap Finder budget setting.
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var userPhoto: UIImage?
    @Published private(set) var stats = WardrobeStats(itemCount: 0, totalWears: 0, neverWornCount: 0, mostWornName: nil)
    @Published var budgetUSD: Int {
        didSet { budgetStore.budgetUSD = budgetUSD }
    }
    @Published var dailyRemindersEnabled: Bool {
        didSet { handleReminderToggle(dailyRemindersEnabled) }
    }

    private let wardrobe: WardrobeRepositoryProtocol
    private let photoStore = UserPhotoStore.shared
    private var budgetStore = BudgetStore()
    private let remindersKey = "settings.dailyRemindersEnabled"

    var cloudSyncEnabled: Bool { AppConfig.shared.isPresent(.supabaseURL) }

    init(container: AppContainer) {
        self.wardrobe = container.wardrobe
        self.budgetUSD = BudgetStore().budgetUSD
        self.dailyRemindersEnabled = UserDefaults.standard.object(forKey: remindersKey) as? Bool ?? true
        self.userPhoto = UserPhotoStore.shared.load()
    }

    func load() async {
        userPhoto = photoStore.load()
        let items = (try? await wardrobe.fetchAll()) ?? []
        stats = WardrobeStats.compute(items)
    }

    func removePhoto() {
        photoStore.delete()
        userPhoto = nil
    }

    private func handleReminderToggle(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: remindersKey)
        Task {
            if enabled {
                await NotificationService.shared.requestAndScheduleDailyReminder()
            } else {
                NotificationService.shared.cancelDailyReminder()
            }
        }
    }
}
