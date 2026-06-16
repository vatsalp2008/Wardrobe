import CoreData
import UIKit
import XCTest
@testable import Wardrobe

/// Phase 1 tests — Core Data persistence round-trip, entity mapping, and dominant-color extraction.
final class Phase1ClosetTests: XCTestCase {

    private func makeRepo() -> CoreDataWardrobeRepository {
        CoreDataWardrobeRepository(stack: .inMemory())
    }

    func testAddAndFetchRoundTrip() async throws {
        let repo = makeRepo()
        let item = ClothingItem(name: "Navy Chinos", category: .bottom, color: ["#1F2D5A"],
                                pattern: .solid, formality: .smartCasual, season: [.fall])
        try await repo.add(item)

        let fetched = try await repo.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        let stored = try XCTUnwrap(fetched.first)
        XCTAssertEqual(stored.id, item.id)
        XCTAssertEqual(stored.name, "Navy Chinos")
        XCTAssertEqual(stored.category, .bottom)
        XCTAssertEqual(stored.color, ["#1F2D5A"])
        XCTAssertEqual(stored.formality, .smartCasual)
        XCTAssertEqual(stored.season, [.fall])
    }

    func testMarkWornPersists() async throws {
        let repo = makeRepo()
        let item = ClothingItem(name: "Tee", category: .top)
        try await repo.add(item)
        try await repo.markWorn(id: item.id, on: Date())

        let fetched = try await repo.fetchAll()
        let stored = try XCTUnwrap(fetched.first)
        XCTAssertEqual(stored.wearCount, 1)
        XCTAssertNotNil(stored.lastWorn)
    }

    func testDeleteRemovesItem() async throws {
        let repo = makeRepo()
        let item = ClothingItem(name: "Blazer", category: .outerwear)
        try await repo.add(item)
        try await repo.delete(id: item.id)
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func testEntityMappingPreservesMultiValueFields() async throws {
        let repo = makeRepo()
        let item = ClothingItem(name: "Multi", category: .dress, color: ["#FFFFFF", "#000000"],
                                pattern: .floral, formality: .formal,
                                season: [.spring, .summer], embedding: [0.1, 0.2, 0.3])
        try await repo.add(item)
        let fetched = try await repo.fetchAll()
        let stored = try XCTUnwrap(fetched.first)
        XCTAssertEqual(stored.color, ["#FFFFFF", "#000000"])
        XCTAssertEqual(stored.season, [.spring, .summer])
        XCTAssertEqual(stored.embedding, [0.1, 0.2, 0.3])
        XCTAssertEqual(stored.pattern, .floral)
    }

    func testDominantColorIgnoresWhiteBackground() {
        // A solid red square on white should yield a non-white dominant color.
        let size = CGSize(width: 40, height: 40)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 8, y: 8, width: 24, height: 24))
        }
        let colors = DominantColor.extract(from: image, maxColors: 1)
        let hex = try? XCTUnwrap(colors.first)
        XCTAssertNotNil(hex)
        if let hex = colors.first {
            XCTAssertTrue(hex.hasPrefix("#"))
            XCTAssertNotEqual(hex, "#FFFFFF")
        }
    }
}
