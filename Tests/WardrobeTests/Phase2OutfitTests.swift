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

    // MARK: - Core Data persistence

    /// One shared stack per test: `.inMemory()` returns a fresh container each call, so the
    /// wardrobe and outfit repositories must be handed the same instance to see each other's rows.
    private func makeRepos() -> (CoreDataWardrobeRepository, CoreDataOutfitRepository) {
        let stack = CoreDataStack.inMemory()
        return (CoreDataWardrobeRepository(stack: stack), CoreDataOutfitRepository(stack: stack))
    }

    private func makeOutfit(items: [ClothingItem], favorited: Bool = false) -> Outfit {
        Outfit(items: items, occasion: .work, trendScore: 0.8,
               weatherSuitability: WeatherRange(minC: 5, maxC: 25),
               generatedBy: "test", isFavorited: favorited, reasoning: "Because")
    }

    func testOutfitRoundTripPreservesItemsAndOrder() async throws {
        let (wardrobe, outfits) = makeRepos()
        let shirt = ClothingItem(name: "Shirt", category: .top)
        let pants = ClothingItem(name: "Pants", category: .bottom)
        let shoes = ClothingItem(name: "Shoes", category: .shoes)
        for item in [shirt, pants, shoes] { try await wardrobe.add(item) }

        let outfit = makeOutfit(items: [shoes, shirt, pants])   // deliberately not closet order
        try await outfits.save([outfit])

        let all = try await outfits.fetchAll()
        let stored = try XCTUnwrap(all.first)
        XCTAssertEqual(stored.id, outfit.id)
        XCTAssertEqual(stored.items.map(\.id), [shoes.id, shirt.id, pants.id])
        XCTAssertEqual(stored.occasion, .work)
        XCTAssertEqual(stored.trendScore, 0.8, accuracy: 0.0001)
        XCTAssertEqual(stored.weatherSuitability, WeatherRange(minC: 5, maxC: 25))
        XCTAssertEqual(stored.reasoning, "Because")
    }

    func testSetFavoritePersists() async throws {
        let (wardrobe, outfits) = makeRepos()
        let shirt = ClothingItem(name: "Shirt", category: .top)
        try await wardrobe.add(shirt)
        let outfit = makeOutfit(items: [shirt])
        try await outfits.save([outfit])

        try await outfits.setFavorite(id: outfit.id, isFavorited: true)
        let all = try await outfits.fetchAll()
        let stored = try XCTUnwrap(all.first)
        XCTAssertTrue(stored.isFavorited)
    }

    func testRecordWornAppendsDate() async throws {
        let (wardrobe, outfits) = makeRepos()
        let shirt = ClothingItem(name: "Shirt", category: .top)
        try await wardrobe.add(shirt)
        let outfit = makeOutfit(items: [shirt])
        try await outfits.save([outfit])

        try await outfits.recordWorn(id: outfit.id, on: Date())
        try await outfits.recordWorn(id: outfit.id, on: Date().addingTimeInterval(86_400))
        let all = try await outfits.fetchAll()
        let stored = try XCTUnwrap(all.first)
        XCTAssertEqual(stored.wornOn.count, 2)
    }

    /// A refresh must not throw away outfits the user favorited or actually wore.
    func testSaveKeepsFavoritedAndWornOutfitsAndPrunesTheRest() async throws {
        let (wardrobe, outfits) = makeRepos()
        let shirt = ClothingItem(name: "Shirt", category: .top)
        try await wardrobe.add(shirt)

        let favorited = makeOutfit(items: [shirt])
        let worn = makeOutfit(items: [shirt])
        let disposable = makeOutfit(items: [shirt])
        try await outfits.save([favorited, worn, disposable])
        try await outfits.setFavorite(id: favorited.id, isFavorited: true)
        try await outfits.recordWorn(id: worn.id, on: Date())

        let fresh = makeOutfit(items: [shirt])
        try await outfits.save([fresh])

        let ids = Set(try await outfits.fetchAll().map(\.id))
        XCTAssertEqual(ids, [favorited.id, worn.id, fresh.id])
        XCTAssertFalse(ids.contains(disposable.id))
    }

    /// Deleting a garment nullifies it out of the outfit rather than cascading the outfit away.
    func testDeletingClothingItemLeavesOutfitIntact() async throws {
        let (wardrobe, outfits) = makeRepos()
        let shirt = ClothingItem(name: "Shirt", category: .top)
        let pants = ClothingItem(name: "Pants", category: .bottom)
        for item in [shirt, pants] { try await wardrobe.add(item) }
        try await outfits.save([makeOutfit(items: [shirt, pants])])

        try await wardrobe.delete(id: shirt.id)

        let all = try await outfits.fetchAll()
        let stored = try XCTUnwrap(all.first)
        XCTAssertEqual(stored.items.map(\.id), [pants.id])
    }
}
