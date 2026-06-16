import Foundation
import UIKit

/// Writes images to the on-disk caches directory and returns a `file://` URL.
/// Used to persist try-on result images locally so they survive relaunch and load instantly
/// on a cache hit (spec §5.3). In Phase 5 the remote Supabase URL supersedes this for sync.
struct LocalImageStore {
    static let shared = LocalImageStore()

    private var directory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
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

    func load(_ urlString: String) -> UIImage? {
        guard let url = URL(string: urlString), url.isFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
