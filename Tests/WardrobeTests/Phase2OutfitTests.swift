import XCTest
@testable import Wardrobe

/// Phase 2 tests — recent-wear soft-exclude logic and weather range behavior.
final class Phase2OutfitTests: XCTestCase {

    private func item(_ name: String, lastWornDaysAgo: Int?) -> ClothingItem {
        let date = lastWornDaysAgo.map { Date().addingTimeInterval(-86_400 * Double($0)) }
        return ClothingItem(name: name, category: .top, lastWorn: date)
    }

    func testRecentlyWornItemsExcludedWhenEnoughRemain() {
        let items = [
            item("A", lastWornDaysAgo: 1),    // recent — excluded
            item("B", lastWornDaysAgo: 2),    // recent — excluded
            item("C", lastWornDaysAgo: 10),
            item("D", lastWornDaysAgo: nil),  // never worn
            item("E", lastWornDaysAgo: 30),
            item("F", lastWornDaysAgo: 8)
        ]
        let candidates = OutfitViewModel.candidateItems(items, excludingWornWithin: 7, now: Date())
        let names = Set(candidates.map(\.name))
        XCTAssertFalse(names.contains("A"))
        XCTAssertFalse(names.contains("B"))
        XCTAssertTrue(names.contains("C"))
        XCTAssertTrue(names.contains("D"))
    }

    func testFallsBackToAllItemsWhenTooFewCandidates() {
        // Only 2 non-recent items < minCandidates (4) → keep everything so outfits can still form.
        let items = [
            item("A", lastWornDaysAgo: 1),
            item("B", lastWornDaysAgo: 1),
            item("C", lastWornDaysAgo: 1),
            item("D", lastWornDaysAgo: 10),
            item("E", lastWornDaysAgo: 30)
        ]
        let candidates = OutfitViewModel.candidateItems(items, excludingWornWithin: 7, now: Date())
        XCTAssertEqual(candidates.count, items.count)
    }

    func testMockGeneratorRespectsWeatherRangeAroundTemperature() async throws {
        let claude = MockClaudeService()
        let weather = WeatherInfo(temperatureC: 20, highC: 24, condition: "Mild", isFallback: true)
        let outfits = try await claude.generateOutfits(
            wardrobe: SampleData.items, weather: weather, occasion: .work, trendKeywords: ["linen"]
        )
        let first = try XCTUnwrap(outfits.first)
        XCTAssertTrue(first.weatherSuitability.contains(20))
    }
}
