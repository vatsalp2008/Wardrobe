import Foundation
import UIKit

/// On-device clothing classification (spec §5.1).
///
/// `OnDeviceMLService` already does the real **dominant-color extraction**. Category, pattern,
/// and formality are returned at low confidence so `ItemReviewView` prompts the user to confirm
/// them — until the trained `ClothingClassifier.mlmodel` (TRADEOFFS F1) is bundled and replaces
/// those predictions.
protocol MLServiceProtocol: Sendable {
    func classify(_ image: UIImage) async throws -> ClothingTags
}

/// Stub used by tests/previews — fixed low-confidence tags.
struct StubMLService: MLServiceProtocol {
    func classify(_ image: UIImage) async throws -> ClothingTags {
        ClothingTags(category: .top, colors: ["#808080"], pattern: .solid,
                     formality: .casual, seasons: [.spring, .fall], confidence: 0.0)
    }
}

/// Real on-device service: extracts dominant colors now; defers the trained classifier (F1).
struct OnDeviceMLService: MLServiceProtocol {
    func classify(_ image: UIImage) async throws -> ClothingTags {
        let colors = DominantColor.extract(from: image, maxColors: 2)
        return ClothingTags(
            category: .top,                 // placeholder until the trained model lands (F1)
            colors: colors.isEmpty ? ["#808080"] : colors,
            pattern: .solid,
            formality: .casual,
            seasons: [],
            // Colors are real; the other three attributes are not predicted yet → force manual review.
            confidence: 0.0
        )
    }
}

/// Extracts dominant color(s) as hex strings from an image, ignoring transparent and
/// near-white pixels (background-removed garments sit on transparency).
enum DominantColor {
    static func extract(from image: UIImage, maxColors: Int = 2) -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        let side = 48
        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: side * side * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Bucket colors into a coarse grid (16 levels per channel) and count occurrences.
        var counts: [Int: Int] = [:]
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = pixels[index], g = pixels[index + 1], b = pixels[index + 2], a = pixels[index + 3]
            if a < 128 { continue }                          // skip transparent background
            if r > 240 && g > 240 && b > 240 { continue }    // skip near-white background
            let key = (Int(r) >> 4) << 8 | (Int(g) >> 4) << 4 | (Int(b) >> 4)
            counts[key, default: 0] += 1
        }

        return counts.sorted { $0.value > $1.value }
            .prefix(maxColors)
            .map { entry in
                let key = entry.key
                let r = (key >> 8 & 0xF) * 17     // expand 4-bit back to 8-bit
                let g = (key >> 4 & 0xF) * 17
                let b = (key & 0xF) * 17
                return String(format: "#%02X%02X%02X", r, g, b)
            }
    }
}
