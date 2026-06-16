import Foundation
import UIKit

/// On-device clothing classification (spec §5.1). Phase 1 loads `ClothingClassifier.mlmodel`
/// (CreateML / MobileNetV3) and extracts dominant colors via Vision; when confidence is below
/// `ClothingTags.manualReviewThreshold` the review screen asks the user to confirm tags.
/// Phase 0 ships `StubMLService`.
protocol MLServiceProtocol: Sendable {
    /// Predicts category / color / pattern / formality / seasons for a segmented garment image.
    func classify(_ image: UIImage) async throws -> ClothingTags
}

struct StubMLService: MLServiceProtocol {
    func classify(_ image: UIImage) async throws -> ClothingTags {
        // Low confidence on purpose so the (future) review screen always prompts manual tagging
        // until the trained model is bundled.
        ClothingTags(
            category: .top,
            colors: ["#808080"],
            pattern: .solid,
            formality: .casual,
            seasons: [.spring, .fall],
            confidence: 0.0
        )
    }
}
