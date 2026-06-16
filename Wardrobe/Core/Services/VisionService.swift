import Foundation
import UIKit

/// On-device garment segmentation / background removal (spec §5.1).
/// Phase 1 implements the real pipeline:
///   `VNGenerateForegroundInstanceMaskRequest` (iOS 17+) →
///   `VNGeneratePersonSegmentationRequest` (iOS 16 fallback) →
///   Remove.bg via `BackgroundRemovalServiceProtocol` when confidence < 0.7.
/// Phase 0 ships `StubVisionService`.
protocol VisionServiceProtocol: Sendable {
    /// Returns the garment on a transparent background, plus the segmentation confidence.
    func segment(_ image: UIImage) async throws -> (image: UIImage, confidence: Double)
}

struct StubVisionService: VisionServiceProtocol {
    func segment(_ image: UIImage) async throws -> (image: UIImage, confidence: Double) {
        (image, 1.0)
    }
}
