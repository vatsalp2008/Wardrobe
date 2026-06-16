import XCTest
@testable import Wardrobe

/// Phase 5 tests — wear-stats computation and the budget setting store.
final class Phase5ProfileTests: XCTestCase {

    func testWardrobeStatsComputesTotalsAndMostWorn() {
        let items = [
            ClothingItem(name: "Tee", category: .top, wearCount: 12),
            ClothingItem(name: "Jeans", category: .bottom, wearCount: 3),
            ClothingItem(name: "Blazer", category: .outerwear, wearCount: 0)
        ]
        let stats = WardrobeStats.compute(items)
        XCTAssertEqual(stats.itemCount, 3)
        XCTAssertEqual(stats.totalWears, 15)
        XCTAssertEqual(stats.neverWornCount, 1)
        XCTAssertEqual(stats.mostWornName, "Tee")
    }

    func testWardrobeStatsEmptyHasNoMostWorn() {
        let stats = WardrobeStats.compute([])
        XCTAssertEqual(stats.itemCount, 0)
        XCTAssertNil(stats.mostWornName)
    }

    func testBudgetStoreDefaultsAndPersists() {
        let name = "budget.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let store = BudgetStore(defaults: defaults)
        XCTAssertEqual(store.budgetUSD, BudgetStore.default)
        store.budgetUSD = 250
        XCTAssertEqual(BudgetStore(defaults: defaults).budgetUSD, 250)
    }
}
