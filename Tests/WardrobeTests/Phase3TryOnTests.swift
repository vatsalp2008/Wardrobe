import UIKit
import XCTest
@testable import Wardrobe

/// Phase 3 tests — daily try-on limiter (cost control) and encrypted photo round-trip.
final class Phase3TryOnTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let name = "tryon.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testLimiterStartsAtDailyLimit() {
        let limiter = DailyTryOnLimiter(defaults: freshDefaults())
        XCTAssertEqual(limiter.remaining(), DailyTryOnLimiter.dailyLimit)
        XCTAssertTrue(limiter.canGenerate())
    }

    func testLimiterDecrementsAndBlocksAtZero() {
        let limiter = DailyTryOnLimiter(defaults: freshDefaults())
        for _ in 0..<DailyTryOnLimiter.dailyLimit { limiter.record() }
        XCTAssertEqual(limiter.remaining(), 0)
        XCTAssertFalse(limiter.canGenerate())
    }

    func testEncryptedPhotoRoundTrip() throws {
        // Render a small test image, save (encrypted), reload, confirm it decodes.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1   // keep points == pixels so the round-trip comparison is exact
        let size = CGSize(width: 20, height: 30)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let store = UserPhotoStore.shared
        store.delete()
        defer { store.delete() }

        XCTAssertFalse(store.hasPhoto)
        try store.save(image)
        XCTAssertTrue(store.hasPhoto)

        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.size.width, size.width, accuracy: 1)
        XCTAssertEqual(loaded.size.height, size.height, accuracy: 1)
    }

    // MARK: - Core Data render cache

    private func makeImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10), format: format).image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }

    func testTryOnResultRoundTripByOutfitID() async throws {
        let repo = CoreDataTryOnRepository(stack: .inMemory())
        let outfitID = UUID()
        let result = TryOnResult(outfitID: outfitID, renderedImageURL: "file:///tmp/a.png")
        try await repo.save(result)

        let cached = try await repo.cachedResult(for: outfitID)
        let stored = try XCTUnwrap(cached)
        XCTAssertEqual(stored.outfitID, outfitID)
        XCTAssertEqual(stored.renderedImageURL, "file:///tmp/a.png")

        let miss = try await repo.cachedResult(for: UUID())
        XCTAssertNil(miss)
    }

    func testSavingSameOutfitTwiceUpsertsSingleRow() async throws {
        let repo = CoreDataTryOnRepository(stack: .inMemory())
        let outfitID = UUID()
        try await repo.save(TryOnResult(outfitID: outfitID, renderedImageURL: "file:///tmp/old.png"))
        try await repo.save(TryOnResult(outfitID: outfitID, renderedImageURL: "file:///tmp/new.png"))

        let cached = try await repo.cachedResult(for: outfitID)
        let stored = try XCTUnwrap(cached)
        XCTAssertEqual(stored.renderedImageURL, "file:///tmp/new.png")
    }

    /// Persisted URLs embed the app-container UUID, which changes on update/restore. The store
    /// must still find the file by name rather than reporting a cache miss.
    func testLocalImageStoreLoadsByFileNameWhenAbsolutePathIsStale() throws {
        let store = LocalImageStore.shared
        let name = "stale-path-test-\(UUID().uuidString)"
        let written = try XCTUnwrap(store.write(makeImage(), name: name))
        defer { try? FileManager.default.removeItem(at: written) }

        let staleURL = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/OLD-UUID/"
                           + written.lastPathComponent)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleURL.path))
        XCTAssertNotNil(store.load(staleURL.absoluteString))
    }
}
