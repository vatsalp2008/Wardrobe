import Foundation
import UIKit

/// Persists garment / try-on images: writes a local thumbnail and uploads the full image
/// to Supabase Storage, returning the remote URL (spec §5.1 / §6.3). Backed by
/// `SupabaseServiceProtocol`, so it returns mock URLs in local-only mode.
protocol ImageStorageManaging: Sendable {
    /// Uploads a PNG (≤ 1024², per spec §5.1) and returns its URL.
    func store(_ image: UIImage, bucket: StorageBucket, fileName: String) async throws -> String
    /// Generates a small thumbnail `Data` blob for offline display in Core Data.
    func thumbnailData(for image: UIImage, maxDimension: CGFloat) -> Data?
}

struct ImageStorageManager: ImageStorageManaging {
    let supabase: SupabaseServiceProtocol

    func store(_ image: UIImage, bucket: StorageBucket, fileName: String) async throws -> String {
        let resized = image.resized(maxDimension: 1024)
        guard let data = resized.pngData() else {
            throw ImageStorageError.encodingFailed
        }
        return try await supabase.uploadImage(data, bucket: bucket, fileName: fileName)
    }

    func thumbnailData(for image: UIImage, maxDimension: CGFloat = 256) -> Data? {
        image.resized(maxDimension: maxDimension).jpegData(compressionQuality: 0.7)
    }
}

enum ImageStorageError: Error {
    case encodingFailed
}

extension UIImage {
    /// Aspect-fit resize so the longest side is at most `maxDimension`. No upscaling.
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
