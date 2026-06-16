import XCTest
@testable import Wardrobe

/// Phase 4 tests — the combinatorial Gap Finder algorithm.
final class Phase4GapTests: XCTestCase {

    private func item(_ name: String, _ category: ClothingCategory,
                      _ formality: FormalityLevel = .casual, pattern: ClothingPattern = .solid) -> ClothingItem {
        ClothingItem(name: name, category: category, pattern: pattern, formality: formality)
    }

    func testCompatibilityRespectsFormalityAndPattern() {
        let casualTop = item("tee", .top, .casual)
        let formalBottom = item("trousers", .bottom, .formal)
        XCTAssertFalse(CombinationMatrix.compatible(casualTop, formalBottom), "formality 2+ apart should clash")

        let plaidTop = item("plaid", .top, .casual, pattern: .plaid)
        let stripedBottom = item("striped", .bottom, .casual, pattern: .striped)
        XCTAssertFalse(CombinationMatrix.compatible(plaidTop, stripedBottom), "two different patterns clash")

        let solidBottom = item("jeans", .bottom, .casual)
        XCTAssertTrue(CombinationMatrix.compatible(plaidTop, solidBottom), "one solid is fine")
    }

    func testValidOutfitCountCountsTopBottomShoes() {
        let items = [
            item("top", .top), item("bottom", .bottom), item("shoes", .shoes)
        ]
        XCTAssertEqual(CombinationMatrix.validOutfitCount(items), 1)
    }

    func testGapAnalysisSurfacesTheMissingCategory() {
        // Wardrobe has tops + shoes but NO bottoms → a bottom should be the top gap.
        let items = [
            item("tee", .top, .casual),
            item("shirt", .top, .smartCasual),
            item("sneakers", .shoes, .casual)
        ]
        let candidates = CombinationMatrix.analyze(items)
        XCTAssertEqual(candidates.first?.category, .bottom)
        XCTAssertGreaterThan(candidates.first?.newOutfitsUnlocked ?? 0, 0)
    }

    func testGapsAreAllPositiveImpact() {
        // The matrix only ever returns candidates that unlock at least one new outfit.
        let items = [item("tee", .top), item("sneakers", .shoes)]
        let gaps = CombinationMatrix.analyze(items)
        XCTAssertTrue(gaps.allSatisfy { $0.newOutfitsUnlocked > 0 })
        XCTAssertFalse(gaps.isEmpty)   // a bottom should register here
    }

    func testMockClaudeRanksTopThreeCandidates() async throws {
        let candidates = [
            GapCandidate(category: .bottom, description: "Navy chinos", formality: .smartCasual,
                         colors: ["#1F2D5A"], newOutfitsUnlocked: 6),
            GapCandidate(category: .shoes, description: "White sneakers", formality: .casual,
                         colors: ["#FFFFFF"], newOutfitsUnlocked: 4),
            GapCandidate(category: .top, description: "White shirt", formality: .smartCasual,
                         colors: ["#FFFFFF"], newOutfitsUnlocked: 2),
            GapCandidate(category: .dress, description: "Black dress", formality: .business,
                         colors: ["#1A1A1A"], newOutfitsUnlocked: 1)
        ]
        let suggestions = try await MockClaudeService().analyzeGap(wardrobe: [], candidates: candidates)
        XCTAssertEqual(suggestions.count, 3)
        XCTAssertEqual(suggestions.first?.missingCategory, .bottom)
        XCTAssertEqual(suggestions.first?.newOutfitsUnlocked, 6)
    }
}
