import CoreImage
import Foundation
import UIKit
import Vision

/// On-device garment segmentation / background removal (spec §5.1).
/// Pipeline: `VNGenerateForegroundInstanceMaskRequest` (iOS 17+) →
/// `VNGeneratePersonSegmentationRequest` (iOS 16 fallback) →
/// `BackgroundRemovalServiceProtocol` (Remove.bg) when confidence < 0.7.
protocol VisionServiceProtocol: Sendable {
    /// Returns the garment on a transparent background, plus the segmentation confidence (0–1).
    func segment(_ image: UIImage) async throws -> (image: UIImage, confidence: Double)
}

/// Stub used by tests/previews: returns the input unchanged with full confidence.
struct StubVisionService: VisionServiceProtocol {
    func segment(_ image: UIImage) async throws -> (image: UIImage, confidence: Double) {
        (image, 1.0)
    }
}

/// Real on-device implementation.
struct LiveVisionService: VisionServiceProtocol {
    /// Below this confidence we hand off to the secondary (Remove.bg) fallback.
    static let confidenceThreshold = 0.7
    let fallback: BackgroundRemovalServiceProtocol

    func segment(_ image: UIImage) async throws -> (image: UIImage, confidence: Double) {
        guard let cgImage = image.cgImage else { return (image, 0) }

        // Primary: foreground-instance mask (best for garments), iOS 17+.
        if #available(iOS 17.0, *), let masked = try? Self.foregroundMasked(cgImage, orientation: image.imageOrientation) {
            return (masked, 1.0)
        }

        // Fallback: person segmentation (iOS 16). Lower confidence — garments on hangers segment poorly.
        if let personMasked = try? Self.personMasked(cgImage, orientation: image.imageOrientation) {
            if Self.confidenceThreshold <= 0.5 { return (personMasked, 0.5) }
            // Confidence below threshold → use the secondary network fallback (mock until Phase 1 key).
            let removed = try await fallback.removeBackground(from: personMasked)
            return (removed, 0.5)
        }

        // Last resort: return original via secondary fallback so the flow never breaks.
        let removed = try await fallback.removeBackground(from: image)
        return (removed, 0.0)
    }

    // MARK: - Vision pipelines

    @available(iOS 17.0, *)
    private static func foregroundMasked(_ cgImage: CGImage, orientation: UIImage.Orientation) throws -> UIImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(orientation))
        try handler.perform([request])
        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw VisionError.noForeground
        }
        let buffer = try result.generateMaskedImage(
            ofInstances: result.allInstances,
            from: handler,
            croppedToInstancesExtent: false
        )
        return uiImage(from: buffer, orientation: orientation)
    }

    private static func personMasked(_ cgImage: CGImage, orientation: UIImage.Orientation) throws -> UIImage {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(orientation))
        try handler.perform([request])
        guard let maskBuffer = request.results?.first?.pixelBuffer else { throw VisionError.noForeground }

        let original = CIImage(cgImage: cgImage)
        var mask = CIImage(cvPixelBuffer: maskBuffer)
        // Scale the mask up to the source image size.
        let scaleX = original.extent.width / mask.extent.width
        let scaleY = original.extent.height / mask.extent.height
        mask = mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let filter = CIFilter(name: "CIBlendWithMask")
        filter?.setValue(original, forKey: kCIInputImageKey)
        filter?.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
        filter?.setValue(mask, forKey: kCIInputMaskImageKey)
        guard let output = filter?.outputImage,
              let cgOut = ciContext.createCGImage(output, from: original.extent) else {
            throw VisionError.compositingFailed
        }
        return UIImage(cgImage: cgOut, scale: 1, orientation: orientation)
    }

    // MARK: - Helpers

    private static let ciContext = CIContext()

    private static func uiImage(from buffer: CVPixelBuffer, orientation: UIImage.Orientation) -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

enum VisionError: Error {
    case noForeground
    case compositingFailed
}
