import Foundation
import UIKit

/// Secondary background-removal fallback used when on-device Vision segmentation
/// confidence is below 0.7 (spec §5.1). Live adapter calls the Remove.bg API in Phase 1;
/// Phase 0 ships `MockBackgroundRemovalService`.
protocol BackgroundRemovalServiceProtocol: Sendable {
    /// Returns an image with the background removed (transparent PNG).
    func removeBackground(from image: UIImage) async throws -> UIImage
}

/// No-op fallback that returns the original image unchanged.
struct MockBackgroundRemovalService: BackgroundRemovalServiceProtocol {
    func removeBackground(from image: UIImage) async throws -> UIImage {
        image
    }
}
