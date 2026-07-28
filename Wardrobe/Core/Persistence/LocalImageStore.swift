import Foundation
import UIKit

/// Writes images to Application Support and returns a `file://` URL.
/// Used to persist try-on result images locally so they survive relaunch and load instantly
/// on a cache hit (spec §5.3). The remote Supabase URL supersedes this once cloud sync is on.
struct LocalImageStore {
    static let shared = LocalImageStore()

    /// Application Support, not caches: iOS evicts the caches directory under storage pressure,
    /// which would silently empty the try-on cache while Core Data still holds the row.
    private var directory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tryon-results", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    func write(_ image: UIImage, name: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = directory.appendingPathComponent("\(name).png")
        try? data.write(to: url)
        return url
    }

    /// Loads a previously written image. Persisted URLs are absolute and embed the app-container
    /// UUID, which changes on app update or device restore, so fall back to resolving the file
    /// name against the current directory before giving up.
    func load(_ urlString: String) -> UIImage? {
        guard let url = URL(string: urlString), url.isFileURL else { return nil }
        if FileManager.default.fileExists(atPath: url.path) {
            return UIImage(contentsOfFile: url.path)
        }
        let relocated = directory.appendingPathComponent(url.lastPathComponent)
        guard FileManager.default.fileExists(atPath: relocated.path) else { return nil }
        return UIImage(contentsOfFile: relocated.path)
    }
}
