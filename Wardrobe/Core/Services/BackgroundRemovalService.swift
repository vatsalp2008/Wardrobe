import Foundation
import UIKit

/// Secondary background-removal fallback used when on-device Vision segmentation
/// confidence is below 0.7 (spec §5.1). A live Remove.bg adapter would slot in here; since the
/// on-device path is sufficient, `AppContainer` wires the no-op mock.
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
