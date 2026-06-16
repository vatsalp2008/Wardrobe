import UIKit
import XCTest
@testable import Wardrobe

/// Phase 0 smoke tests — verify the model logic, mock services, and repositories that the
/// rest of the app is built on. These establish the test target and the 60%+ coverage habit.
final class Phase0SmokeTests: XCTestCase {

    func testFormalityOrdering() {
        XCTAssertLessThan(FormalityLevel.casual, .formal)
        XCTAssertLessThan(FormalityLevel.smartCasual, .business)
        XCTAssertEqual(FormalityLevel.allCases.count, 4)
    }

    func testRecentWearWindow() {
        let recent = Date().addingTimeInterval(-86_400 * 2)   // 2 days ago
        let old = Date().addingTimeInterval(-86_400 * 10)     // 10 days ago
        XCTAssertTrue(recent.isWithinLast(days: 7))
        XCTAssertFalse(old.isWithinLast(days: 7))
    }

    func testWeatherRangeContains() {
        let range = WeatherRange(minC: 10, maxC: 22)
        XCTAssertTrue(range.contains(15))
        XCTAssertFalse(range.contains(30))
    }

    func testStubMLConfidenceTriggersManualReview() async throws {
        let tags = try await StubMLService().classify(UIImage())
        XCTAssertLessThan(tags.confidence, ClothingTags.manualReviewThreshold)
    }

    func testMockClaudeGeneratesAtMostFiveOutfits() async throws {
        let claude = MockClaudeService()
        let outfits = try await claude.generateOutfits(
            wardrobe: SampleData.items,
            weather: WeatherInfo(temperatureC: 18, highC: 22, condition: "Mild", isFallback: true),
            occasion: .casual,
            trendKeywords: []
        )
        XCTAssertFalse(outfits.isEmpty)
        XCTAssertLessThanOrEqual(outfits.count, 5)
        XCTAssertTrue(outfits.allSatisfy { !$0.items.isEmpty })
    }

    func testInMemoryWardrobeMarkWornIncrementsCount() async throws {
        let repo = InMemoryWardrobeRepository(seed: SampleData.items)
        let first = try await repo.fetchAll().first!
        let before = first.wearCount
        try await repo.markWorn(id: first.id, on: Date())
        let after = try await repo.fetchAll().first(where: { $0.id == first.id })!
        XCTAssertEqual(after.wearCount, before + 1)
        XCTAssertNotNil(after.lastWorn)
    }

    func testGapCacheValidity() async throws {
        let repo = InMemoryGapRepository()
        let fresh = await repo.isCacheValid(maxAge: 60)
        XCTAssertFalse(fresh, "empty cache is not valid")
        try await repo.save([SampleData.sampleGap])
        let nowValid = await repo.isCacheValid(maxAge: 60 * 60 * 24)
        XCTAssertTrue(nowValid)
    }
}
