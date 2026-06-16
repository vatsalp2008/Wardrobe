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
}
