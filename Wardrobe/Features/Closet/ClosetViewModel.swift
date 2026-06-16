import SwiftUI

/// Backs the Closet grid: loads items from the wardrobe repository and applies filters
/// (spec §7.1). Reactive state is published for the View.
@MainActor
final class ClosetViewModel: ObservableObject {
    @Published private(set) var items: [ClothingItem] = []
    @Published private(set) var isLoading = false
    @Published var categoryFilter: ClothingCategory?

    private let wardrobe: WardrobeRepositoryProtocol

    init(container: AppContainer) {
        self.wardrobe = container.wardrobe
    }

    var filteredItems: [ClothingItem] {
        guard let categoryFilter else { return items }
        return items.filter { $0.category == categoryFilter }
    }

    /// Categories present in the wardrobe, for the filter bar.
    var availableCategories: [ClothingCategory] {
        ClothingCategory.allCases.filter { category in items.contains { $0.category == category } }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        items = (try? await wardrobe.fetchAll()) ?? []
    }

    func delete(_ item: ClothingItem) async {
        try? await wardrobe.delete(id: item.id)
        await load()
    }

    func markWorn(_ item: ClothingItem) async {
        try? await wardrobe.markWorn(id: item.id, on: Date())
        await load()
    }
}
