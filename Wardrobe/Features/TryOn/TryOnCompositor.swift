import UIKit

/// Renders a local "preview" composite for the **mock** try-on path (no real IDM-VTON call):
/// the user's photo with a strip of garment thumbnails and a badge. Gives the compare view a
/// visibly distinct result on the Simulator without any network. The live path uses the real
/// Replicate render instead.
enum TryOnCompositor {
    static func preview(person: UIImage, items: [ClothingItem]) -> UIImage {
        let size = person.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            person.draw(in: CGRect(origin: .zero, size: size))

            // Bottom strip background.
            let stripHeight = size.height * 0.16
            let stripRect = CGRect(x: 0, y: size.height - stripHeight, width: size.width, height: stripHeight)
            UIColor.black.withAlphaComponent(0.45).setFill()
            ctx.fill(stripRect)

            // Garment thumbnails along the strip.
            let pad = stripHeight * 0.15
            let thumb = stripHeight - pad * 2
            var x = pad
            for item in items.prefix(5) {
                let rect = CGRect(x: x, y: stripRect.minY + pad, width: thumb, height: thumb)
                if let data = item.thumbnailData, let image = UIImage(data: data) {
                    image.draw(in: rect)
                } else {
                    UIColor.white.withAlphaComponent(0.25).setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: 6).fill()
                }
                x += thumb + pad
            }

            // "Preview" badge.
            let text = "PREVIEW"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width * 0.04, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            text.draw(at: CGPoint(x: pad, y: pad), withAttributes: attrs)
        }
    }
}
